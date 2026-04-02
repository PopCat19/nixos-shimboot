#!/usr/bin/env bash

# test-runtime.sh
#
# Purpose: Unit tests for runtime.sh
#
# This module:
# - Tests command checking
# - Tests CI detection
# - Tests dry-run behavior

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../tools/lib" && pwd)"

# shellcheck source=logging.sh
source "$LIB_DIR/logging.sh"
# shellcheck source=runtime.sh
source "$LIB_DIR/runtime.sh"

test_has_command() {
	if ! has_command bash; then
		echo "FAIL: has_command bash"
		return 1
	fi

	if has_command this_command_definitely_does_not_exist_12345; then
		echo "FAIL: has_command non-existent"
		return 1
	fi

	echo "PASS: has_command"
	return 0
}

test_require_cmds() {
	if ! require_cmds bash cat; then
		echo "FAIL: require_cmds valid commands"
		return 1
	fi

	if require_cmds bash this_command_does_not_exist_12345 2>/dev/null; then
		echo "FAIL: require_cmds missing command"
		return 1
	fi

	echo "PASS: require_cmds"
	return 0
}

test_is_ci() {
	unset CI
	if is_ci; then
		echo "FAIL: is_ci without CI set"
		return 1
	fi

	export CI=true
	if ! is_ci; then
		echo "FAIL: is_ci with CI=true"
		return 1
	fi

	export CI=1
	if ! is_ci; then
		echo "FAIL: is_ci with CI=1"
		return 1
	fi

	unset CI
	echo "PASS: is_ci"
	return 0
}

test_safe_exec() {
	export DRY_RUN=1

	if ! safe_exec echo "test" >/dev/null 2>&1; then
		echo "FAIL: safe_exec with DRY_RUN=1"
		return 1
	fi

	unset DRY_RUN
	if ! safe_exec echo "test" >/dev/null 2>&1; then
		echo "FAIL: safe_exec without DRY_RUN"
		return 1
	fi

	echo "PASS: safe_exec"
	return 0
}

main() {
	test_has_command
	test_require_cmds
	test_is_ci
	test_safe_exec
	echo "All runtime tests passed"
}

main "$@"
