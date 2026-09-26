#!/usr/bin/env bash
# Event hook entry point.
#   close.sh workspace   ← workspace.closed
#   close.sh agent       ← pane.closed
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source lib/herdr.sh
source lib/plugin.sh

kind=${1:?usage: close.sh workspace|agent}
field=$([[ $kind == agent ]] && echo pane_id || echo workspace_id)
id=$(jq -r --arg k "$field" '.data[$k] // empty' <<< "${HERDR_PLUGIN_EVENT_JSON:-}")

[[ -n "$id" ]] && on_close "$kind" "$id"
exit 0
