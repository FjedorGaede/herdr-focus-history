#!/usr/bin/env bash
# Run every test file. Exit non-zero if any fails.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

failed=0
for t in test-*.sh; do
  "$BASH" "$t" || failed=$((failed + 1))
  echo
done

if [[ $failed -eq 0 ]]; then echo "✅ all tests passed"; else echo "❌ $failed test file(s) failed"; fi
[[ $failed -eq 0 ]]
