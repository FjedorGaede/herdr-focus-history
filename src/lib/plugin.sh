#!/usr/bin/env bash
# Plugin logic: what happens on a focus event and on back/forward.
#
# Talks to herdr only through the interface in herdr.sh:
#   herdr_workspace_ids   ids of open workspaces, space-separated
#   herdr_agent_ids       pane ids of running agents, space-separated
#   herdr_focus KIND ID   focus a workspace or agent pane
#
# KIND is "workspace" or "agent".

_plugin_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_plugin_dir/history.sh"
source "$_plugin_dir/store.sh"

# Ids of KIND that currently exist in herdr.
_alive_ids() { # kind
  case $1 in
    workspace) herdr_workspace_ids ;;
    agent)     herdr_agent_ids ;;
    *)         echo "unknown kind: $1" >&2; return 2 ;;
  esac
}

# A workspace or pane got focus. Record it as a jump.
# Panes that aren't running an agent are ignored.
#
# Our own back/forward jumps also end up here (herdr fires the event).
# That's harmless: they land on the current entry, and pushing the
# current entry is a no-op.
on_focus() { # kind id
  local kind=$1 id=$2
  case $kind in
    workspace) ;;
    agent)     [[ " $(herdr_agent_ids) " == *" $id "* ]] || return 0 ;;
    *)         echo "unknown kind: $kind" >&2; return 2 ;;
  esac
  [[ -n "$id" ]] || return 0

  store_load "$kind"
  history_push "$id"
  store_save "$kind"
}

# A workspace or pane was closed: forget it.
# Closing a workspace doesn't fire pane.closed for its panes, so the agent
# history is re-checked against herdr's live agent list as well.
on_close() { # kind id
  local kind=$1 id=$2
  case $kind in
    workspace) store_load workspace; history_remove "$id"; store_save workspace
               store_load agent; history_prune $(herdr_agent_ids); store_save agent ;;
    agent)     store_load agent; history_remove "$id"; store_save agent ;;
    *)         echo "unknown kind: $kind" >&2; return 2 ;;
  esac
}

# Jump one step back or forward, skipping workspaces/agents that were closed.
on_navigate() { # kind back|forward
  local kind=$1 direction=$2 alive
  alive=$(_alive_ids "$kind") || return

  store_load "$kind"
  history_prune $alive
  if history_step "$direction"; then
    store_save "$kind"       # save first: herdr fires on_focus during the jump
    herdr_focus "$kind" "${HIST[$POS]}"
  else
    store_save "$kind"       # nowhere to go, but keep the pruning
  fi
}
