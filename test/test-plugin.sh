#!/usr/bin/env bash
# Tests for the plugin logic (on_focus, on_navigate).
# The herdr interface (src/lib/herdr.sh) is replaced by the functions below.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source lib/assert.sh
source ../src/lib/plugin.sh

# ── herdr interface stand-ins ───────────────────────────
WORKSPACES="w1 w2 w3"     # what "exists" in herdr
AGENTS="w1:p1 w2:p1 w3:p1"
FOCUSED=()                # every focus call, in order

herdr_workspace_ids() { echo "$WORKSPACES"; }
herdr_agent_ids()     { echo "$AGENTS"; }
herdr_focus()         { FOCUSED+=("$1 $2"); }

last_focus() { (( ${#FOCUSED[@]} )) && echo "${FOCUSED[${#FOCUSED[@]} - 1]}"; }

# Fresh state for every test (each test runs in its own subshell).
setup() {
  export HERDR_PLUGIN_STATE_DIR
  HERDR_PLUGIN_STATE_DIR=$(mktemp -d)
}

# ── recording ───────────────────────────────────────────

test_workspace_back_after_two_switches() {
  setup
  on_focus workspace w1; on_focus workspace w2
  on_navigate workspace back
  assert_eq "workspace w1" "$(last_focus)"
}

test_agent_back_after_two_focuses() {
  setup
  on_focus agent w1:p1; on_focus agent w2:p1
  on_navigate agent back
  assert_eq "agent w1:p1" "$(last_focus)"
}

test_focusing_a_shell_keeps_agent_forward_history() {
  # A non-agent pane must not count as an agent jump. If it did, it would
  # drop the forward history (and pruning would hide the evidence later).
  setup
  on_focus agent w1:p1; on_focus agent w2:p1
  on_navigate agent back;  on_focus agent w1:p1
  on_focus agent w9:shell
  on_navigate agent forward
  assert_eq "agent w2:p1" "$(last_focus)"
}

test_history_survives_between_runs() {
  setup
  on_focus workspace w1; on_focus workspace w2; on_focus workspace w3
  ( on_navigate workspace back )             # separate process, like herdr
  FOCUSED=()
  on_navigate workspace back
  assert_eq "workspace w1" "$(last_focus)"
}

# ── navigating ──────────────────────────────────────────

test_back_then_forward_returns() {
  setup
  on_focus workspace w1; on_focus workspace w2
  on_navigate workspace back;    on_focus workspace w1   # herdr echoes our own jump
  on_navigate workspace forward
  assert_eq "workspace w2" "$(last_focus)"
}

test_forward_from_oldest_entry() {
  # Regression: `(( n++ ))` from 0 returned false and set -e aborted.
  setup
  on_focus workspace w1; on_focus workspace w2; on_focus workspace w3
  on_navigate workspace back; on_navigate workspace back   # now at w1
  on_navigate workspace forward
  assert_eq "workspace w2" "$(last_focus)"
}

test_own_jump_is_not_recorded() {
  setup
  on_focus workspace w1; on_focus workspace w2; on_focus workspace w3
  on_navigate workspace back;    on_focus workspace w2   # echo must not truncate w3
  on_navigate workspace forward
  assert_eq "workspace w3" "$(last_focus)"
}

test_agent_jump_survives_workspace_event() {
  # Jumping to an agent in another workspace fires workspace.focused AND
  # pane.focused. Neither may break the agent history.
  setup
  on_focus agent w1:p1; on_focus agent w2:p1; on_focus agent w3:p1
  on_navigate agent back;  on_focus workspace w2; on_focus agent w2:p1
  on_navigate agent forward
  assert_eq "agent w3:p1" "$(last_focus)"
}

test_back_at_start_does_nothing() {
  setup
  on_focus workspace w1
  on_navigate workspace back
  assert_eq "" "$(last_focus)"
}

test_forward_at_end_does_nothing() {
  setup
  on_focus workspace w1; on_focus workspace w2
  on_navigate workspace forward
  assert_eq "" "$(last_focus)"
}

test_empty_history_does_nothing() {
  setup
  on_navigate workspace back; on_navigate agent forward
  assert_eq "" "$(last_focus)"
}

test_closed_workspace_is_skipped() {
  setup
  on_focus workspace w1; on_focus workspace w2; on_focus workspace w3
  WORKSPACES="w1 w3"
  on_navigate workspace back
  assert_eq "workspace w1" "$(last_focus)"
}

test_closed_agent_is_skipped() {
  setup
  on_focus agent w1:p1; on_focus agent w2:p1; on_focus agent w3:p1
  AGENTS="w1:p1 w3:p1"
  on_navigate agent back
  assert_eq "agent w1:p1" "$(last_focus)"
}

test_workspace_and_agent_histories_are_separate() {
  setup
  on_focus workspace w1; on_focus agent w2:p1; on_focus workspace w3; on_focus agent w3:p1
  on_navigate workspace back
  assert_eq "workspace w1" "$(last_focus)"
  on_navigate agent back
  assert_eq "agent w2:p1" "$(last_focus)"
}

test_history_saved_before_focus() {
  # herdr fires the focus event while we're still inside herdr_focus;
  # that handler must already see the new position.
  setup
  on_focus workspace w1; on_focus workspace w2; on_focus workspace w3
  herdr_focus() { FOCUSED+=("$1 $2"); on_focus "$1" "$2"; }   # echo, synchronously
  on_navigate workspace back
  on_navigate workspace forward
  assert_eq "workspace w3" "$(last_focus)"
}

# ── close events ────────────────────────────────────────

# History as saved on disk, oldest first.
saved() { store_load "$1"; echo ${HIST[@]+"${HIST[@]}"}; }

test_workspace_close_event_removes_it() {
  setup
  on_focus workspace w1; on_focus workspace w2; on_focus workspace w3
  on_close workspace w2
  assert_eq "w1 w3" "$(saved workspace)"
}

test_workspace_close_event_removes_its_agents() {
  # herdr fires no pane.closed for the panes of a closed workspace.
  setup
  on_focus agent w1:p1; on_focus agent w2:p1; on_focus agent w3:p1
  AGENTS="w1:p1 w3:p1"                     # herdr's view after the close
  on_close workspace w2
  assert_eq "w1:p1 w3:p1" "$(saved agent)"
}

test_pane_close_event_removes_agent() {
  setup
  on_focus agent w1:p1; on_focus agent w2:p1; on_focus agent w3:p1
  on_close agent w2:p1
  assert_eq "w1:p1 w3:p1" "$(saved agent)"
}

test_pane_close_event_leaves_workspaces_alone() {
  setup
  on_focus workspace w1; on_focus workspace w2
  on_close agent w2:p1
  assert_eq "w1 w2" "$(saved workspace)"
}

test_closing_a_non_agent_pane_changes_nothing() {
  # pane.closed fires for every pane, shells included.
  setup
  on_focus workspace w1; on_focus workspace w2
  on_focus agent w1:p1; on_focus agent w2:p1
  on_close agent w9:shell || { echo "    on_close failed"; exit 1; }
  assert_eq "w1:p1 w2:p1" "$(saved agent)"
  assert_eq "w1 w2" "$(saved workspace)"
}

test_closing_a_pane_with_empty_history_is_fine() {
  setup
  on_close agent w1:p1 || { echo "    on_close failed"; exit 1; }
  on_close workspace w1 || { echo "    on_close failed"; exit 1; }
  assert_eq "" "$(saved agent)"
}

test_unknown_kind_is_rejected() {
  setup
  assert_fails on_focus window w1
  assert_fails on_navigate window back
  assert_fails on_close window w1
}

echo "plugin:"
run_tests
