#!/usr/bin/env bash
# Checks that the tests actually catch bugs: breaks the code in known ways,
# one at a time, and expects the test suite to fail for every one.
# Works on a temporary copy; the real source is never touched.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# name | file | sed expression that introduces the bug
# (portable sed only: must run with both GNU and BSD/macOS sed)
MUTANTS=(
  "push: repeat of current entry recorded|src/lib/history.sh|s/\[\[ \"\${HIST\[\$POS\]}\" == \"\$id\" \]\]/false/"
  "push: forward history not dropped|src/lib/history.sh|s/HIST=(\"\${HIST\[@\]:0:\$((POS + 1))}\")/:/"
  "push: length cap ignored|src/lib/history.sh|s/if (( overflow > 0 ))/if false/"
  "push: POS not moved to end|src/lib/history.sh|s/POS=\$(( \${#HIST\[@\]} - 1 ))/:/"
  "step: back moves forward|src/lib/history.sh|s/POS=\$((POS - 1))/POS=\$((POS + 1))/"
  "step: no bounds check going back|src/lib/history.sh|s/(( POS > 0 )) || return 1/:/"
  "step: no bounds check going forward|src/lib/history.sh|s/(( POS < \${#HIST\[@\]} - 1 )) || return 1/:/"
  "prune: nothing removed|src/lib/history.sh|s/\[\[ \"\$alive\" == \*\" \$id \"\* \]\] || continue/:/"
  "prune: neighbours not merged|src/lib/history.sh|s/\[\[ \"\${kept\[\${#kept\[@\]} - 1\]}\" == \"\$id\" \]\]/false/"
  "focus: non-agent panes recorded|src/lib/plugin.sh|s/\\[\\[ \" \$(herdr_agent_ids) \" == \*\" \$id \"\* \\]\\] || return 0/:/"
  "focus: unknown kind accepted|src/lib/plugin.sh|/^on_focus()/,/^}/s/\*)         echo \"unknown kind: \$kind\" >\&2; return 2 ;;/*) ;;/"
  "close: fails for panes that aren't agents|src/lib/plugin.sh|s/    agent)     store_load agent; history_remove \"\$id\"; store_save agent ;;/    agent)     [[ \" \$(herdr_agent_ids) \" == *\" \$id \"* ]] || return 1; store_load agent; history_remove \"\$id\"; store_save agent ;;/"
  "close: workspace close ignored|src/lib/plugin.sh|s/workspace) store_load workspace; history_remove \"\$id\"/workspace) store_load workspace; :/"
  "close: agents of closed workspace kept|src/lib/plugin.sh|s/store_load agent; history_prune \$(herdr_agent_ids); store_save agent ;;/: ;;/"
  "navigate: closed entries not pruned|src/lib/plugin.sh|s/^  history_prune \$alive/  :/"
  "navigate: history not saved before focus|src/lib/plugin.sh|s/    store_save \"\$kind\"       # save first/    : #/"
)

caught=0 missed=0
for m in "${MUTANTS[@]}"; do
  IFS='|' read -r name file expr <<< "$m"
  tmp=$(mktemp -d)
  cp -r "$ROOT/src" "$ROOT/test" "$tmp/"
  sed -i.bak "$expr" "$tmp/$file"
  if cmp -s "$tmp/$file" "$tmp/$file.bak"; then
    printf '  ⚠ %-45s sed did not change anything — fix the mutant\n' "$name"
    missed=$((missed + 1))
  elif "$BASH" "$tmp/test/run-all.sh" > /dev/null 2>&1; then
    printf '  ✗ %-45s NOT caught\n' "$name"
    missed=$((missed + 1))
  else
    printf '  ✓ %-45s caught\n' "$name"
    caught=$((caught + 1))
  fi
  rm -rf "$tmp"
done

echo "  $caught/$((caught + missed)) bugs caught"
[[ $missed -eq 0 ]]
