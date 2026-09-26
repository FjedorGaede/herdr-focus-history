#!/usr/bin/env bash
# Throwaway herdr server for end-to-end tests.
#
# Everything (config, sockets, plugin registry, state) lives in a temp HOME,
# and every herdr call runs under `env -i`, so a herdr you're already running
# — whose HERDR_SOCKET_PATH may be in your environment — is never touched.
#
#   e2e_start          start a fresh server with this plugin linked
#   e2e_stop           stop it and delete the temp dir
#   h ARGS...          run the herdr CLI against it
#   eventually CMD...  retry CMD until it succeeds (hooks run asynchronously)

E2E_HERDR=${E2E_HERDR:-$(command -v herdr)}
E2E_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

h() {
  env -i \
    HOME="$E2E_HOME" PATH="$E2E_PATH" TERM=xterm-256color \
    XDG_CONFIG_HOME="$E2E_HOME/config" XDG_STATE_HOME="$E2E_HOME/state" \
    XDG_DATA_HOME="$E2E_HOME/data" XDG_RUNTIME_DIR="$E2E_HOME/run" \
    "$E2E_HERDR" "$@"
}

e2e_start() {
  [[ -x "$E2E_HERDR" ]] || { echo "herdr not found (set E2E_HERDR)" >&2; return 1; }
  # /tmp, not $TMPDIR: macOS TMPDIR paths are long, and socket paths max out at 104 chars
  E2E_HOME=$(mktemp -d /tmp/herdr-e2e.XXXXXX)
  # PATH for plugin hooks: bash + jq, nothing from the user's shell setup.
  # system bash first (3.2 on macOS), then wherever jq lives
  E2E_PATH="/usr/bin:/bin:$(dirname "$(command -v jq)")"
  mkdir -p "$E2E_HOME/run" && chmod 700 "$E2E_HOME/run"

  h server > "$E2E_HOME/server.out" 2>&1 &
  E2E_PID=$!
  eventually h workspace list > /dev/null || { cat "$E2E_HOME/server.out" >&2; return 1; }

  # Safety check: the server must be the one in our temp dir.
  grep -q "api socket: $E2E_HOME/" "$E2E_HOME/server.out" \
    || { echo "server is not isolated — refusing to continue" >&2; e2e_stop; return 1; }

  h plugin link "$E2E_REPO" > /dev/null
}

e2e_stop() {
  [[ -n "${E2E_HOME:-}" ]] || return 0
  h server stop > /dev/null 2>&1 || true
  kill "$E2E_PID" 2>/dev/null || true
  wait "$E2E_PID" 2>/dev/null || true
  rm -rf "$E2E_HOME"
  E2E_HOME=
}

# Retry until the command succeeds; ~5s max.
eventually() {
  local i
  for i in $(seq 50); do
    "$@" && return 0
    sleep 0.1
  done
  return 1
}

# ── herdr helpers ───────────────────────────────────────

new_workspace()     { h workspace create | jq -r '.result.workspace.workspace_id'; }
close_workspace()   { h workspace close "$1" > /dev/null; }
focus_workspace()   { h workspace focus "$1" > /dev/null; }
focused_workspace() { h workspace list | jq -r '.result.workspaces[] | select(.focused) | .workspace_id'; }

# First pane of a workspace.
pane_of()           { h pane list | jq -r --arg w "$1" '[.result.panes[] | select(.workspace_id == $w)][0].pane_id'; }
# Turn a plain shell pane into an "agent" without running one.
make_agent()        { h pane report-agent --source e2e --agent pi --state idle "$1" > /dev/null; }
focus_agent()       { h agent focus "$1" > /dev/null; }
focused_agent()     { h agent list | jq -r '.result.agents[] | select(.focused) | .pane_id'; }

# Run a plugin action, like pressing its key.
press()             { h plugin action invoke "focus-history.$1" > /dev/null; }

# Plugin state, as the hooks wrote it.
history_of()        { paste -sd' ' "$E2E_HOME/state/herdr/plugins/focus-history/$1-history.txt" 2>/dev/null; }

# herdr's own record of every hook/action run by this plugin.
_plugin_logs()  { h plugin log list --plugin focus-history | jq -c '.result.logs'; }
# No hook or action still running.
hooks_idle()    { [[ $(_plugin_logs | jq '[.[] | select(.status == "running")] | length') == 0 ]]; }
# Print every failed run (empty = none). herdr swallows hook errors, so this
# is the only place a crashing hook shows up.
failed_hooks()  { _plugin_logs | jq -r '.[] | select(.exit_code != null and .exit_code != 0) | "\(.event // .action_id) exit=\(.exit_code): \(.stderr)"'; }
