#!/usr/bin/env bash

# run-tests.sh
#
# Purpose: Run all unit tests
#
# This module:
# - Executes all test scripts in tests/

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -d "$SCRIPT_DIR" ]]; then
	TESTS_DIR="$SCRIPT_DIR"
else
	TESTS_DIR="$(cd "$SCRIPT_DIR/../tests" && pwd)"
fi

run_test() {
	local test_script="$1"
	local name
	name=$(basename "$test_script" .sh)

	echo "Running: $name"
	if "$test_script"; then
		echo "✓ $name passed"
		return 0
	else
		echo "✗ $name failed"
		return 1
	fi
}

main() {
	local failed=0
	local passed=0

	if [[ ! -d "$TESTS_DIR" ]]; then
		echo "No tests directory found"
		exit 1
	fi

	for test_script in "$TESTS_DIR"/test-*.sh; do
		if [[ -x "$test_script" ]]; then
			if run_test "$test_script"; then
				((passed++))
			else
				((failed++))
			fi
		fi
	done

	echo
	echo "Results: $passed passed, $failed failed"

	if [[ $failed -gt 0 ]]; then
		exit 1
	fi
}

main "$@"
