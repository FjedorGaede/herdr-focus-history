#!/usr/bin/env bash
# Minimal test helpers. Each test_* function runs in its own subshell,
# and a failed assertion exits that subshell immediately.
# (Don't rely on `set -e` for this: bash disables it inside functions
# called from an `if`, so later assertions would mask earlier failures.)

assert_eq() { # expected actual [message]
  if [[ "$1" != "$2" ]]; then
    printf '    expected: %q\n    actual:   %q\n' "$1" "$2"
    [[ -n "${3:-}" ]] && printf '    (%s)\n' "$3"
    exit 1
  fi
}

assert_fails() { # command...
  if "$@"; then
    printf '    expected failure: %s\n' "$*"
    exit 1
  fi
}

# Run every test_* function defined in the calling file.
run_tests() {
  local name failed=0 total=0
  for name in $(declare -F | awk '{print $3}' | grep '^test_'); do
    total=$((total + 1))
    if ( "$name" ); then
      echo "  ✓ ${name#test_}"
    else
      echo "  ✗ ${name#test_}"
      failed=$((failed + 1))
    fi
  done
  echo "  $((total - failed))/$total passed"
  [[ $failed -eq 0 ]]
}
