#!/usr/bin/env bash
# Runs every headless GDScript test suite and fails on the first non-zero exit.
set -uo pipefail

GODOT="${GODOT_BIN:-godot}"
FAILED=0
SUITES=0
for test_file in tests/test_*.gd; do
  if [ "$(basename "$test_file")" = "test_runner.gd" ]; then continue; fi
  SUITES=$((SUITES + 1))
  echo ""
  echo "=========== ${test_file} ==========="
  set +e
  timeout 300 "$GODOT" --headless --path . --script "res://${test_file}"
  STATUS=$?
  set -e
  if [ "$STATUS" -ne 0 ]; then
    echo "!!! ${test_file} exited with ${STATUS}"
    FAILED=1
  fi
done
echo ""
echo "Ran ${SUITES} suites."
exit $FAILED
