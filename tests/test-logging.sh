#!/usr/bin/env bash

# test-logging.sh
#
# Purpose: Unit tests for logging.sh
#
# This module:
# - Tests color output functions
# - Tests log level functions

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../tools/lib" && pwd)"

# shellcheck source=logging.sh
source "$LIB_DIR/logging.sh"

test_log_functions() {
	local output

	output=$(log_info "test message" 2>&1)
	if [[ "$output" != *"test message"* ]]; then
		echo "FAIL: log_info"
		return 1
	fi

	output=$(log_warn "warning test" 2>&1)
	if [[ "$output" != *"warning test"* ]]; then
		echo "FAIL: log_warn"
		return 1
	fi

	output=$(log_error "error test" 2>&1)
	if [[ "$output" != *"error test"* ]]; then
		echo "FAIL: log_error"
		return 1
	fi

	output=$(log_success "success test" 2>&1)
	if [[ "$output" != *"success test"* ]]; then
		echo "FAIL: log_success"
		return 1
	fi

	output=$(log_step "STEP" "step test" 2>&1)
	if [[ "$output" != *"step test"* ]]; then
		echo "FAIL: log_step"
		return 1
	fi

	output=$(log_section "section test" 2>&1)
	if [[ "$output" != *"section test"* ]]; then
		echo "FAIL: log_section"
		return 1
	fi

	echo "PASS: logging functions"
	return 0
}

test_no_color() {
	local output
	export NO_COLOR=1

	output=$(log_info "test" 2>&1)
	if [[ "$output" == *$'\033'* ]]; then
		echo "FAIL: NO_COLOR not respected"
		return 1
	fi

	echo "PASS: NO_COLOR support"
	return 0
}

main() {
	test_log_functions
	test_no_color
	echo "All logging tests passed"
}

main "$@"
