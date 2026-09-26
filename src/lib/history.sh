#!/usr/bin/env bash
# Pure jumplist logic. No I/O, no herdr.
#
# Operates on two globals:
#   HIST  array of entry ids, oldest first
#   POS   index of the current entry in HIST
#
# Written for bash 3.2 (macOS default): no mapfile, no namerefs.

: "${MAX_HISTORY:=100}"

# Record a new jump to <id>, like vim's jumplist:
# drop everything after the current entry, append, cap the length.
# Jumping to the entry you're already on is a no-op.
history_push() { # id
  local id=$1

  if (( ${#HIST[@]} > 0 )) && [[ "${HIST[$POS]}" == "$id" ]]; then
    return 0
  fi

  if (( ${#HIST[@]} > 0 )); then
    HIST=("${HIST[@]:0:$((POS + 1))}")
  fi
  HIST+=("$id")

  local overflow=$(( ${#HIST[@]} - MAX_HISTORY ))
  if (( overflow > 0 )); then
    HIST=("${HIST[@]:$overflow}")
  fi

  POS=$(( ${#HIST[@]} - 1 ))
}

# Move POS one step. Fails (returns 1) without moving at either end.
history_step() { # back|forward
  case $1 in
    back)    (( POS > 0 )) || return 1
             POS=$((POS - 1)) ;;
    forward) (( POS < ${#HIST[@]} - 1 )) || return 1
             POS=$((POS + 1)) ;;
    *)       return 2 ;;
  esac
}

# Keep only entries whose id is in <alive...>. POS stays on the same entry,
# or moves to the nearest older surviving one if the current entry is gone.
# Neighbours that become equal after removal are merged into one.
history_prune() { # alive...
  local alive=" $* "
  local kept=() new_pos=0 i id

  for i in "${!HIST[@]}"; do
    id=${HIST[$i]}
    [[ "$alive" == *" $id "* ]] || continue
    if (( ${#kept[@]} > 0 )) && [[ "${kept[${#kept[@]} - 1]}" == "$id" ]]; then
      :   # same as previous kept entry → merge
    else
      kept+=("$id")
    fi
    (( i <= POS )) && new_pos=$(( ${#kept[@]} - 1 ))
  done

  HIST=(${kept[@]+"${kept[@]}"})
  POS=$new_pos
}

# Drop every occurrence of <id> (e.g. a workspace that was closed).
# Same position rules as history_prune.
history_remove() { # id
  local id=$1 keep=() entry
  for entry in ${HIST[@]+"${HIST[@]}"}; do
    [[ "$entry" == "$id" ]] || keep+=("$entry")
  done
  history_prune ${keep[@]+"${keep[@]}"}
}
