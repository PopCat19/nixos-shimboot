#!/usr/bin/env bash

# Test Bwrap Workaround Script
#
# Purpose: Test bwrap LSM workaround functionality
# Dependencies: bwrap, mkdir
# Related: bwrap-lsm-workaround.sh, setup-bwrap-workaround.sh
#
# This script:
# - Tests basic bwrap functionality
# - Tests tmpfs workaround
# - Verifies bind mount conversion
# - Validates cache directory creation

set -Eeuo pipefail

# Colors & Logging
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
NC='\033[0m'

echo -e "${BLUE}[INFO]${NC} Testing bwrap LSM workaround..."

# Configuration
BWRAP_SAFE="/run/wrappers/bin/bwrap-safe"
BWRAP_REGULAR="/run/wrappers/bin/bwrap"
BWRAP_CACHE_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/bwrap-cache"

# Create cache directory for testing
mkdir -p "$BWRAP_CACHE_DIR"
chmod 700 "$BWRAP_CACHE_DIR"

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Test helper function
run_test() {
	local test_name="$1"
	local test_command="$2"

	TESTS_TOTAL=$((TESTS_TOTAL + 1))
	echo -e "${BLUE}[TEST ${TESTS_TOTAL}]${NC} ${test_name}"

	if eval "$test_command" 2>/dev/null; then
		echo -e "${GREEN}[PASS]${NC} ${test_name}"
		TESTS_PASSED=$((TESTS_PASSED + 1))
		return 0
	else
		echo -e "${RED}[FAIL]${NC} ${test_name}"
		TESTS_FAILED=$((TESTS_FAILED + 1))
		return 1
	fi
}

# Test 1: Check if bwrap-safe exists (optional - only after rebuild)
if [[ -f "${BWRAP_SAFE}" ]]; then
	run_test "bwrap-safe wrapper exists" "test -f ${BWRAP_SAFE}"
else
	echo -e "${YELLOW}[SKIP]${NC} bwrap-safe wrapper not found (will be available after rebuild)"
fi

# Test 2: Check if regular bwrap exists
run_test "Regular bwrap wrapper exists" "test -f ${BWRAP_REGULAR}"

# Test 3: Test basic bwrap functionality
run_test "Basic bwrap execution" "${BWRAP_REGULAR} --ro-bind / / --dev /dev --proc /proc echo 'basic test'"

# Test 4: Test bwrap-safe basic functionality (if available)
if [[ -f "${BWRAP_SAFE}" ]]; then
	run_test "bwrap-safe basic execution" "${BWRAP_SAFE} --ro-bind / / --dev /dev --proc /proc echo 'safe basic test'"
else
	echo -e "${YELLOW}[SKIP]${NC} bwrap-safe basic execution (wrapper not available)"
fi

# Test 5: Test bwrap-safe with tmpfs (should work with workaround)
if [[ -f "${BWRAP_SAFE}" ]]; then
	run_test "bwrap-safe with tmpfs workaround" "${BWRAP_SAFE} --ro-bind / / --dev /dev --proc /proc --tmpfs /tmp echo 'tmpfs test'"
else
	echo -e "${YELLOW}[SKIP]${NC} bwrap-safe with tmpfs workaround (wrapper not available)"
fi

# Test 6: Verify cache directory is created
run_test "Cache directory creation" "test -d ${BWRAP_CACHE_DIR}"

# Test 7: Verify cache directory permissions
run_test "Cache directory permissions" "test -r ${BWRAP_CACHE_DIR} && test -w ${BWRAP_CACHE_DIR}"

# Test 8: Test multiple tmpfs mounts
if [[ -f "${BWRAP_SAFE}" ]]; then
	run_test "Multiple tmpfs mounts" "${BWRAP_SAFE} --ro-bind / / --dev /dev --proc /proc --tmpfs /tmp --tmpfs /var/tmp echo 'multi tmpfs test'"
else
	echo -e "${YELLOW}[SKIP]${NC} Multiple tmpfs mounts (wrapper not available)"
fi

# Test 9: Test bind mount functionality
if [[ -f "${BWRAP_SAFE}" ]]; then
	run_test "Bind mount functionality" "${BWRAP_SAFE} --ro-bind / / --dev /dev --proc /proc --bind /tmp /mnt echo 'bind test'"
else
	echo -e "${YELLOW}[SKIP]${NC} Bind mount functionality (wrapper not available)"
fi

# Test 10: Test complex bwrap command
if [[ -f "${BWRAP_SAFE}" ]]; then
	run_test "Complex bwrap command" "${BWRAP_SAFE} --ro-bind / / --dev /dev --proc /proc --tmpfs /tmp --bind /home /home echo 'complex test'"
else
	echo -e "${YELLOW}[SKIP]${NC} Complex bwrap command (wrapper not available)"
fi

# Test 11: Test bwrap-lsm-workaround script directly
if command -v bwrap-lsm-workaround >/dev/null 2>&1; then
	run_test "bwrap-lsm-workaround script" "bwrap-lsm-workaround --ro-bind / / --dev /dev --proc /proc --tmpfs /tmp echo 'workaround script test'"
else
	echo -e "${YELLOW}[SKIP]${NC} bwrap-lsm-workaround script (not in PATH)"
fi

# Summary
echo ""
echo -e "${BLUE}[SUMMARY]${NC}"
echo -e "Total tests: ${TESTS_TOTAL}"
echo -e "${GREEN}Passed: ${TESTS_PASSED}${NC}"
echo -e "${RED}Failed: ${TESTS_FAILED}${NC}"

if [[ ${TESTS_FAILED} -eq 0 ]]; then
	echo -e "${GREEN}[SUCCESS]${NC} All tests passed!"
	exit 0
else
	echo -e "${RED}[FAILURE]${NC} Some tests failed"
	exit 1
fi
