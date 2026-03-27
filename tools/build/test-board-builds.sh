#!/usr/bin/env bash

# test-board-builds.sh
#
# Purpose: Test Nix flake builds for all supported ChromeOS boards
#
# This module:
# - Tests building chromeos-shim packages for each supported board
# - Validates flake structure and raw-rootfs packages for each profile
# - Reports build success/failure summary

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/logging.sh"

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

# Discover available profiles
PROFILE_DIR="shimboot_config/profiles"
AVAILABLE_PROFILES=()
if [ -d "$PROFILE_DIR" ]; then
	for profile_dir in "$PROFILE_DIR"/*/; do
		[ -d "$profile_dir" ] || continue
		profile_name=$(basename "$profile_dir")
		AVAILABLE_PROFILES+=("$profile_name")
	done
fi

# Default to 'default' profile if none found
if [ ${#AVAILABLE_PROFILES[@]} -eq 0 ]; then
	AVAILABLE_PROFILES=("default")
fi

# Results tracking
declare -A BUILD_RESULTS
FAILED_BOARDS=()
SUCCESSFUL_BOARDS=()
FAILED_PROFILES=()
SUCCESSFUL_PROFILES=()

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

	echo "Profiles tested: ${#AVAILABLE_PROFILES[@]}"
	echo "Successful profiles: ${#SUCCESSFUL_PROFILES[@]}"
	echo "Failed profiles: ${#FAILED_PROFILES[@]}"
	echo ""

	if [ ${#SUCCESSFUL_PROFILES[@]} -gt 0 ]; then
		log_success "Successfully built profiles:"
		for profile in "${SUCCESSFUL_PROFILES[@]}"; do
			echo "  OK $profile"
		done
		echo ""
	fi

	if [ ${#FAILED_PROFILES[@]} -gt 0 ]; then
		log_error "Failed profiles:"
		for profile in "${FAILED_PROFILES[@]}"; do
			echo "  FAIL $profile"
		done
		echo ""
	fi

	echo "Total boards tested: ${#SUPPORTED_BOARDS[@]}"
	echo "Successful builds: ${#SUCCESSFUL_BOARDS[@]}"
	echo "Failed builds: ${#FAILED_BOARDS[@]}"
	echo ""

	if [ ${#SUCCESSFUL_BOARDS[@]} -gt 0 ]; then
		log_success "Successfully built boards:"
		for board in "${SUCCESSFUL_BOARDS[@]}"; do
			echo "  OK $board (${BUILD_RESULTS[$board]})"
		done
		echo ""
	fi

	if [ ${#FAILED_BOARDS[@]} -gt 0 ]; then
		log_error "Failed boards:"
		for board in "${FAILED_BOARDS[@]}"; do
			echo "  FAIL $board (${BUILD_RESULTS[$board]})"
		done
		echo ""
	fi

	# Overall result
	if [ ${#FAILED_BOARDS[@]} -eq 0 ] && [ ${#FAILED_PROFILES[@]} -eq 0 ]; then
		log_success "All board and profile builds passed! Recovery should work for all supported boards."
		return 0
	else
		log_error "Some builds failed. Recovery may not work for all boards."
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

	# Check if in the right directory
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

	# Test raw-rootfs packages for each profile (they're board-independent)
	echo "Testing board-independent packages (profiles)"
	echo "----------------------------------------------"

	for profile in "${AVAILABLE_PROFILES[@]}"; do
		echo "Profile: $profile"
		local profile_failed=false

		if nix build ".#raw-rootfs-${profile}" --no-link --fallback --quiet; then
			log_success "Successfully built raw-rootfs-${profile}"
		else
			log_error "Failed to build raw-rootfs-${profile}"
			profile_failed=true
		fi

		if nix build ".#raw-rootfs-${profile}-minimal" --no-link --fallback --quiet; then
			log_success "Successfully built raw-rootfs-${profile}-minimal"
		else
			log_error "Failed to build raw-rootfs-${profile}-minimal"
			profile_failed=true
		fi

		if [ "$profile_failed" = true ]; then
			FAILED_PROFILES+=("$profile")
		else
			SUCCESSFUL_PROFILES+=("$profile")
		fi
		echo ""
	done

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
	if [ ${#FAILED_BOARDS[@]} -eq 0 ] && [ ${#FAILED_PROFILES[@]} -eq 0 ]; then
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
	echo "And tests raw-rootfs packages for each profile:"
	echo "  ${AVAILABLE_PROFILES[*]}"
	echo ""
	echo "The script will:"
	echo "  1. Run a basic flake check"
	echo "  2. Test build for each board"
	echo "  3. Test build for each profile's raw-rootfs packages"
	echo "  4. Display a summary of results"
	echo "  5. Exit with success if all builds pass, failure otherwise"
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
