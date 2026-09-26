#!/usr/bin/env bash
# Unit tests for the pure history logic (no herdr involved).
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source lib/assert.sh
source ../src/lib/history.sh

# ── push ────────────────────────────────────────────────

test_push_onto_empty_history() {
  HIST=(); POS=0
  history_push a
  assert_eq "a" "${HIST[*]}"
  assert_eq 0 "$POS"
}

test_push_appends_and_moves_to_end() {
  HIST=(a b); POS=1
  history_push c
  assert_eq "a b c" "${HIST[*]}"
  assert_eq 2 "$POS"
}

test_push_same_as_current_is_ignored() {
  HIST=(a b); POS=1
  history_push b
  assert_eq "a b" "${HIST[*]}"
  assert_eq 1 "$POS"
}

test_push_drops_forward_history() {
  HIST=(a b c d); POS=1
  history_push x
  assert_eq "a b x" "${HIST[*]}"
  assert_eq 2 "$POS"
}

test_push_caps_length_dropping_oldest() {
  HIST=(a b c); POS=2
  MAX_HISTORY=3 history_push d
  assert_eq "b c d" "${HIST[*]}"
  assert_eq 2 "$POS"
}

# ── step ────────────────────────────────────────────────

test_back_moves_one_older() {
  HIST=(a b c); POS=2
  history_step back
  assert_eq 1 "$POS"
}

test_forward_moves_one_newer() {
  HIST=(a b c); POS=0
  history_step forward
  assert_eq 1 "$POS"
}

test_back_at_start_fails_and_stays() {
  HIST=(a b); POS=0
  assert_fails history_step back
  assert_eq 0 "$POS"
}

test_forward_at_end_fails_and_stays() {
  HIST=(a b); POS=1
  assert_fails history_step forward
  assert_eq 1 "$POS"
}

test_step_on_empty_history_fails() {
  HIST=(); POS=0
  assert_fails history_step back
  assert_fails history_step forward
}

# ── prune ───────────────────────────────────────────────

test_prune_removes_dead_entries() {
  HIST=(a b c d); POS=3
  history_prune a c d
  assert_eq "a c d" "${HIST[*]}"
}

test_prune_keeps_position_on_same_entry() {
  HIST=(a b c d); POS=3       # on d
  history_prune a c d
  assert_eq 2 "$POS" "still on d"
}

test_prune_current_entry_moves_to_nearest_older() {
  HIST=(a b c); POS=1         # on b, which is gone
  history_prune a c
  assert_eq "a c" "${HIST[*]}"
  assert_eq 0 "$POS" "fell back to a"
}

test_prune_removes_consecutive_dead_entries() {
  HIST=(a b c d e); POS=4
  history_prune a e
  assert_eq "a e" "${HIST[*]}"
  assert_eq 1 "$POS"
}

test_prune_merges_neighbours_that_become_equal() {
  HIST=(a b a); POS=2         # after removing b: a a → a
  history_prune a
  assert_eq "a" "${HIST[*]}"
  assert_eq 0 "$POS"
}

test_prune_everything_leaves_empty_history() {
  HIST=(a b); POS=1
  history_prune
  assert_eq 0 "${#HIST[@]}"
  assert_eq 0 "$POS"
}

# ── remove ──────────────────────────────────────────────

test_remove_drops_every_occurrence() {
  HIST=(a b a c); POS=3
  history_remove a
  assert_eq "b c" "${HIST[*]}"
  assert_eq 1 "$POS" "still on c"
}

test_remove_current_entry_moves_to_nearest_older() {
  HIST=(a b c); POS=1
  history_remove b
  assert_eq "a c" "${HIST[*]}"
  assert_eq 0 "$POS"
}

test_remove_unknown_id_changes_nothing() {
  HIST=(a b c); POS=1
  history_remove x
  assert_eq "a b c" "${HIST[*]}"
  assert_eq 1 "$POS"
}

test_remove_last_entry_leaves_empty_history() {
  HIST=(a); POS=0
  history_remove a
  assert_eq 0 "${#HIST[@]}"
  assert_eq 0 "$POS"
}

echo "history:"
run_tests
