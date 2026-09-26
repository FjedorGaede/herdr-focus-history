#!/usr/bin/env bash
# Event hook entry point.
#   record.sh workspace   ← workspace.focused
#   record.sh agent       ← pane.focused
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source lib/herdr.sh
source lib/plugin.sh

kind=${1:?usage: record.sh workspace|agent}
field=$([[ $kind == agent ]] && echo pane_id || echo workspace_id)
id=$(jq -r --arg k "$field" '.data[$k] // empty' <<< "${HERDR_PLUGIN_EVENT_JSON:-}")

on_focus "$kind" "$id"
