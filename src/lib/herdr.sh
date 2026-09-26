#!/usr/bin/env bash
# The herdr interface: the only code that talks to herdr.
# Tests replace these three functions with their own.

_herdr() {
  "${HERDR_BIN_PATH:-herdr}" "$@"
}

herdr_workspace_ids() {
  _herdr workspace list | jq -r '[.result.workspaces[].workspace_id] | join(" ")'
}

herdr_agent_ids() {
  _herdr agent list | jq -r '[.result.agents[].pane_id] | join(" ")'
}

herdr_focus() { # workspace|agent id
  _herdr "$1" focus "$2" > /dev/null
}
