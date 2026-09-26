#!/usr/bin/env bash
# Load/save a history (HIST + POS) from the plugin's state directory.
# One pair of files per kind: <kind>-history.txt (one id per line), <kind>-pos.txt

store_dir() {
  echo "${HERDR_PLUGIN_STATE_DIR:?HERDR_PLUGIN_STATE_DIR not set}"
}

store_load() { # kind
  local dir; dir=$(store_dir)
  local file="$dir/$1-history.txt" line
  HIST=()
  if [[ -f "$file" ]]; then
    while IFS= read -r line; do
      [[ -n "$line" ]] && HIST+=("$line")
    done < "$file"
  fi
  POS=$(cat "$dir/$1-pos.txt" 2>/dev/null || echo 0)
  (( POS >= 0 && POS < ${#HIST[@]} )) || POS=$(( ${#HIST[@]} > 0 ? ${#HIST[@]} - 1 : 0 ))
}

store_save() { # kind
  local dir; dir=$(store_dir)
  mkdir -p "$dir"
  if (( ${#HIST[@]} > 0 )); then
    printf '%s\n' "${HIST[@]}" > "$dir/$1-history.txt"
  else
    : > "$dir/$1-history.txt"
  fi
  echo "$POS" > "$dir/$1-pos.txt"
}
