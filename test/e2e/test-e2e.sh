#!/usr/bin/env bash
# End-to-end tests: a real (throwaway) herdr server with this plugin linked.
# Every test gets a fresh server. Needs herdr and jq; set E2E_HERDR to pick
# a specific herdr binary.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ../lib/assert.sh
source harness.sh

# Each test runs in a subshell; start a server and always clean it up.
setup() { e2e_start || exit 1; trap e2e_stop EXIT; }

# Call at the end of every test: all hooks finished and none crashed.
assert_hooks_ok() {
  eventually hooks_idle
  assert_eq "" "$(failed_hooks)" "failed hook runs"
}

ends_with() { [[ " $(history_of "$1")" == *" $2" ]]; }  # kind id
lacks()     { [[ " $(history_of "$1") " != *" $2 "* ]]; }

# Conditions for `eventually`. They must be functions: an inline
# `eventually [ "$(focused_workspace)" = x ]` would evaluate $(...) only once.
on_workspace() { [[ "$(focused_workspace)" == "$1" ]]; }
on_agent()     { [[ "$(focused_agent)" == "$1" ]]; }
on_pane()      { [[ "$(h pane current | jq -r '.result.pane.pane_id')" == "$1" ]]; }
pane_gone()    { [[ "$(h pane list | jq -r --arg p "$1" '[.result.panes[] | select(.pane_id == $p)] | length')" == 0 ]]; }

# Focus a workspace and wait until the plugin has recorded it.
visit_workspace() { focus_workspace "$1"; eventually ends_with workspace "$1"; }
visit_agent()     { focus_agent "$1";     eventually ends_with agent "$1"; }

# Three workspaces, each with its first pane turned into an agent.
# Sets W1 W2 W3 and A1 A2 A3.
# A plain "home" workspace is created first and keeps the focus: herdr only
# focuses the first workspace it creates, and fires no event when you focus
# what's already focused, so every visit in a test must be a real change.
three_workspaces_with_agents() {
  HOME_WS=$(new_workspace)
  W1=$(new_workspace); W2=$(new_workspace); W3=$(new_workspace)
  A1=$(pane_of "$W1"); A2=$(pane_of "$W2"); A3=$(pane_of "$W3")
  make_agent "$A1"; make_agent "$A2"; make_agent "$A3"
}

# ── tests ───────────────────────────────────────────────

test_workspace_back_and_forward() {
  setup; three_workspaces_with_agents
  visit_workspace "$W1"; visit_workspace "$W2"; visit_workspace "$W3"
  press workspace-back
  eventually on_workspace "$W2"; assert_eq "$W2" "$(focused_workspace)"
  press workspace-back
  eventually on_workspace "$W1"; assert_eq "$W1" "$(focused_workspace)"
  press workspace-forward
  eventually on_workspace "$W2"; assert_eq "$W2" "$(focused_workspace)"
  assert_hooks_ok
}

test_agent_back_and_forward_across_workspaces() {
  setup; three_workspaces_with_agents
  visit_agent "$A1"; visit_agent "$A2"; visit_agent "$A3"
  press agent-back
  eventually on_agent "$A2"; assert_eq "$A2" "$(focused_agent)"
  press agent-forward
  eventually on_agent "$A3"; assert_eq "$A3" "$(focused_agent)"
  assert_hooks_ok
}

test_closing_a_workspace_removes_it_and_its_agents() {
  setup; three_workspaces_with_agents
  visit_agent "$A1"; visit_agent "$A2"; visit_agent "$A3"
  close_workspace "$W2"
  eventually lacks workspace "$W2"; assert_eq "" "$(lacks workspace "$W2" || echo "$W2 still in history")"
  eventually lacks agent "$A2";     assert_eq "" "$(lacks agent "$A2" || echo "$A2 still in history")"
  press agent-back
  eventually on_agent "$A1"; assert_eq "$A1" "$(focused_agent)" "skipped the closed one"
  assert_hooks_ok
}

test_closing_a_pane_removes_its_agent() {
  setup; three_workspaces_with_agents
  extra=$(h pane split "$A3" --direction right | jq -r '.result.pane.pane_id')
  make_agent "$extra"
  visit_agent "$A3"; visit_agent "$extra"
  h pane close "$extra" > /dev/null
  eventually lacks agent "$extra"; assert_eq "" "$(lacks agent "$extra" || echo "$extra still in history")"
  assert_hooks_ok
}

test_focusing_a_shell_keeps_agent_forward_history() {
  setup; three_workspaces_with_agents
  shell=$(h pane split "$A1" --direction right | jq -r '.result.pane.pane_id')   # not an agent
  visit_agent "$A1"; visit_agent "$A2"
  press agent-back
  eventually on_agent "$A1"
  h pane focus --pane "$A1" --direction right > /dev/null                       # focus the shell
  eventually on_pane "$shell"
  eventually hooks_idle
  press agent-forward
  eventually on_agent "$A2"; assert_eq "$A2" "$(focused_agent)"
  assert_hooks_ok
}

test_histories_are_separate() {
  setup; three_workspaces_with_agents
  visit_workspace "$W1"; visit_workspace "$W3"
  visit_agent "$A2"; visit_agent "$A3"
  assert_eq "$A2 $A3" "$(history_of agent | awk '{print $(NF-1), $NF}')"
  assert_eq "" "$(history_of workspace | tr ' ' '\n' | grep ':' || true)" "no pane ids in workspace history"
  assert_hooks_ok
}

test_closing_a_shell_pane_is_harmless() {
  # pane.closed fires for shells too; the hook must cope and change nothing.
  setup; three_workspaces_with_agents
  shell=$(h pane split "$A1" --direction right | jq -r '.result.pane.pane_id')
  visit_agent "$A1"; visit_agent "$A2"
  before=$(history_of agent)
  h pane close "$shell" > /dev/null
  eventually pane_gone "$shell"
  eventually hooks_idle
  assert_eq "$before" "$(history_of agent)"
  press agent-back
  eventually on_agent "$A1"; assert_eq "$A1" "$(focused_agent)"
  assert_hooks_ok
}

echo "e2e (herdr $("$E2E_HERDR" --version 2>/dev/null | awk '{print $2}')):"
run_tests
