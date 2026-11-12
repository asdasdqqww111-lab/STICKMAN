#!/usr/bin/env bash
# Runs every headless GDScript test suite. Exits non-zero on the first failure.
set -uo pipefail

GODOT="${GODOT_BIN:-godot}"
FAILED=0
for test_file in tests/test_*.gd; do
  echo "=== ${test_file} ==="
  if ! "$GODOT" --headless --path . --quiet --script "res://${test_file}" 2>&1 | tee /tmp/current_test.log; then
    echo "!!! ${test_file} exited non-zero"
    FAILED=1
  fi
  # GDScript suites use a custom harness that prints FAIL lines and exits via quit(code).
  if grep -qE "^(FAIL|ERROR|SCRIPT ERROR)" /tmp/current_test.log; then
    echo "!!! ${test_file} reported failures"
    FAILED=1
  fi
done
exit $FAILED
