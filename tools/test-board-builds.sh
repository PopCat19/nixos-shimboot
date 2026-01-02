#!/usr/bin/env bash

# Test Board Builds Script
#
# Purpose: Test Nix flake builds for all supported ChromeOS boards to verify recovery functionality
# Dependencies: nix, jq
# Related: flake.nix, manifests/*.nix
#
# This script tests building chromeos-shim packages for each supported board,
# ensuring recovery images can be built successfully.
#
# Usage:
#   ./tools/test-board-builds.sh

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
	echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
	echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
	echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
	echo -e "${RED}[ERROR]${NC} $1"
}

# Supported ChromeOS boards (from flake.nix)
SUPPORTED_BOARDS=(
	"dedede"
	"octopus"
	"zork"
	"nissa"
	"hatch"
	"grunt"
	"snappy"
)

# Results tracking
declare -A BUILD_RESULTS
FAILED_BOARDS=()
SUCCESSFUL_BOARDS=()

# Function to test build for a single board
test_board_build() {
	local board="$1"
	log_info "Testing build for board: $board"

	# Test chromeos-shim package (this is the critical one for recovery)
	local shim_package="chromeos-shim-${board}"
	local success=true

	# Test chromeos-shim package
	log_info "Testing ${shim_package}..."
	if nix flake show --json | jq -e ".packages.\"x86_64-linux\".\"${shim_package}\"" >/dev/null 2>&1; then
		if nix build ".#${shim_package}" --no-link --fallback --quiet; then
			log_success "Successfully built ${shim_package}"
		else
			log_error "Failed to build ${shim_package}"
			success=false
		fi
	else
		log_warning "Package ${shim_package} not found in flake outputs"
		success=false
	fi

	# Skip recovery package testing for now since it requires large downloads
	# The shim package is the critical component for recovery functionality
	log_info "Skipping chromeos-recovery-${board} test (requires large download)"

	# Record results
	if [ "$success" = true ]; then
		BUILD_RESULTS[$board]="SUCCESS"
		SUCCESSFUL_BOARDS+=("$board")
		return 0
	else
		BUILD_RESULTS[$board]="BUILD_FAILED"
		FAILED_BOARDS+=("$board")
		return 1
	fi
}

# Function to run basic flake check first
run_flake_check() {
	log_info "Running basic flake check..."

	# Skip full flake check since recovery packages may need to download large files
	# Just verify the flake structure is valid
	if nix flake show --quiet >/dev/null 2>&1; then
		log_success "Basic flake structure check passed"
		return 0
	else
		log_error "Basic flake structure check failed"
		return 1
	fi
}

# Function to display results summary
show_results() {
	echo ""
	log_info "=== BUILD TEST RESULTS SUMMARY ==="
	echo ""

	echo "Total boards tested: ${#SUPPORTED_BOARDS[@]}"
	echo "Successful builds: ${#SUCCESSFUL_BOARDS[@]}"
	echo "Failed builds: ${#FAILED_BOARDS[@]}"
	echo ""

	if [ ${#SUCCESSFUL_BOARDS[@]} -gt 0 ]; then
		log_success "Successfully built boards:"
		for board in "${SUCCESSFUL_BOARDS[@]}"; do
			echo "  ✓ $board (${BUILD_RESULTS[$board]})"
		done
		echo ""
	fi

	if [ ${#FAILED_BOARDS[@]} -gt 0 ]; then
		log_error "Failed boards:"
		for board in "${FAILED_BOARDS[@]}"; do
			echo "  ✗ $board (${BUILD_RESULTS[$board]})"
		done
		echo ""
	fi

	# Overall result
	if [ ${#FAILED_BOARDS[@]} -eq 0 ]; then
		log_success "All board builds passed! Recovery should work for all supported boards."
		return 0
	else
		log_error "Some board builds failed. Recovery may not work for all boards."
		return 1
	fi
}

# Function to display detailed results in JSON format
show_json_results() {
	local json_output="{"
	json_output+='"timestamp":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",'
	json_output+='"total_boards":'${#SUPPORTED_BOARDS[@]}','
	json_output+='"successful_builds":'${#SUCCESSFUL_BOARDS[@]}','
	json_output+='"failed_builds":'${#FAILED_BOARDS[@]}','
	json_output+='"results":{'

	local first=true
	for board in "${SUPPORTED_BOARDS[@]}"; do
		if [ "$first" = true ]; then
			first=false
		else
			json_output+=","
		fi
		json_output+='"'$board'":"${BUILD_RESULTS[$board]}"'
	done

	json_output+="}}"

	echo "$json_output"
}

# Main execution
main() {
	echo "ChromeOS Shimboot Board Build Test"
	echo "=================================="
	echo ""

	# Check if we're in the right directory
	if [ ! -f "flake.nix" ]; then
		log_error "flake.nix not found. Please run this script from the project root."
		exit 1
	fi

	# Run basic flake check first
	if ! run_flake_check; then
		log_error "Basic flake check failed. Aborting board tests."
		exit 1
	fi

	echo ""
	log_info "Starting board build tests..."
	echo ""

	# Test raw-rootfs packages once (they're board-independent)
	echo "Testing board-independent packages"
	echo "-----------------------------------"

	if nix build ".#raw-rootfs" --no-link --fallback --quiet; then
		log_success "Successfully built raw-rootfs"
	else
		log_error "Failed to build raw-rootfs"
	fi

	if nix build ".#raw-rootfs-minimal" --no-link --fallback --quiet; then
		log_success "Successfully built raw-rootfs-minimal"
	else
		log_error "Failed to build raw-rootfs-minimal"
	fi

	echo ""

	# Test each board's ChromeOS packages
	for board in "${SUPPORTED_BOARDS[@]}"; do
		echo "Testing board: $board"
		echo "------------------------"

		if test_board_build "$board"; then
			echo ""
		else
			echo ""
			log_warning "Continuing with next board..."
			echo ""
		fi
	done

	# Show results
	show_results

	# Show JSON results if requested
	if [ "${1:-}" = "--json" ]; then
		echo ""
		log_info "JSON results:"
		show_json_results
	fi

	# Exit with appropriate code
	if [ ${#FAILED_BOARDS[@]} -eq 0 ]; then
		exit 0
	else
		exit 1
	fi
}

# Help function
show_help() {
	echo "Usage: $0 [OPTIONS]"
	echo ""
	echo "Test flake builds for each ChromeOS board to ensure recovery works."
	echo ""
	echo "Options:"
	echo "  --json    Output results in JSON format"
	echo "  --help    Show this help message"
	echo ""
	echo "This script tests the raw-rootfs package build for each supported board:"
	echo "  ${SUPPORTED_BOARDS[*]}"
	echo ""
	echo "The script will:"
	echo "  1. Run a basic flake check"
	echo "  2. Test build for each board"
	echo "  3. Display a summary of results"
	echo "  4. Exit with success if all builds pass, failure otherwise"
}

# Parse command line arguments
case "${1:-}" in
--help | -h)
	show_help
	exit 0
	;;
*)
	main "$@"
	;;
esac
