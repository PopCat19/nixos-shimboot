#!/usr/bin/env bash

# push-to-cachix.sh
#
# Purpose: Push Nix derivations to Cachix binary cache
#
# This module:
# - Pushes Nix derivations (shim, recovery, kernel, initramfs, rootfs)
# - Optionally pushes ChromeOS chunk derivations to cache CDN pulls
# - Supports dry-run and selective push modes

set -Eeuo pipefail

readonly BLUE='\033[0;34m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly NC='\033[0m'

log_info() { printf "${BLUE}[INFO]${NC} %s\n" "$*" >&2; }
log_success() { printf "${GREEN}[SUCCESS]${NC} %s\n" "$*" >&2; }
log_warn() { printf "${YELLOW}[WARN]${NC} %s\n" "$*" >&2; }
log_error() { printf "${RED}[ERROR]${NC} %s\n" "$*" >&2; }

# Configuration
CACHE="shimboot-systemd-nixos"
BOARD=""
ROOTFS_FLAVOR="full"
DRIVERS_MODE="vendor"
SKIP_DERIVATIONS=0
SKIP_CHUNKS=0
DRY_RUN=0

usage() {
	cat <<'EOF'
Usage: push-to-cachix.sh --board BOARD [OPTIONS]

Options:
    --board BOARD              Target board (required)
    --rootfs FLAVOR            Rootfs variant (full, minimal)
    --drivers MODE             Driver mode (vendor, inject, both, none)
    --skip-derivations         Skip pushing Nix derivations
    --skip-chunks              Skip pushing ChromeOS chunk derivations
    --dry-run                  Show what would be done

Examples:
    # Push all derivations (shim, recovery, kernel, initramfs, rootfs, chunks)
    ./push-to-cachix.sh --board dedede

    # Push derivations without chunks
    ./push-to-cachix.sh --board dedede --skip-chunks
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
	case "$1" in
	--board)
		BOARD="${2:-}"
		shift 2
		;;
	--rootfs)
		ROOTFS_FLAVOR="${2:-full}"
		shift 2
		;;
	--drivers)
		DRIVERS_MODE="${2:-vendor}"
		shift 2
		;;
	--skip-derivations)
		SKIP_DERIVATIONS=1
		shift
		;;
	--skip-chunks)
		SKIP_CHUNKS=1
		shift
		;;
	--dry-run)
		DRY_RUN=1
		shift
		;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		log_error "Unknown option: $1"
		usage
		exit 1
		;;
	esac
done

# Validate arguments
if [[ -z "$BOARD" ]]; then
	log_error "Board is required (--board BOARD)"
	usage
	exit 1
fi

# Check dependencies
for cmd in cachix nix; do
	if ! command -v "$cmd" >/dev/null 2>&1; then
		log_error "Missing dependency: $cmd"
		exit 1
	fi
done

# CI detection
is_ci() {
	[[ "${CI:-}" == "true" ]] ||
		[[ -n "${GITHUB_ACTIONS:-}" ]] ||
		[[ -n "${GITLAB_CI:-}" ]] ||
		[[ -n "${JENKINS_HOME:-}" ]]
}

# Safe execution wrapper
safe_exec() {
	if [[ "$DRY_RUN" -eq 1 ]]; then
		log_info "[DRY-RUN] Would execute: $*"
	else
		"$@"
	fi
}

# Push Nix derivations
push_derivations() {
	local board="$1"
	local rootfs_attr="raw-rootfs"

	if [[ "$ROOTFS_FLAVOR" == "minimal" ]]; then
		rootfs_attr="raw-rootfs-minimal"
	fi

	log_info "Pushing Nix derivations for board: $board"

	local derivations=(
		".#chromeos-shim-${board}"
		".#chromeos-recovery-${board}"
		".#extracted-kernel-${board}"
		".#initramfs-patching-${board}"
		".#${rootfs_attr}"
	)

	for drv in "${derivations[@]}"; do
		log_info "Pushing $drv..."

		if [[ "$DRY_RUN" -eq 1 ]]; then
			# For dry-run, just check if derivation exists without building
			if ! nix eval --raw --impure --accept-flake-config "$drv" >/dev/null 2>&1; then
				log_warn "Failed to evaluate $drv, skipping push"
				continue
			fi
			local store_path
			store_path=$(nix path-info --impure --accept-flake-config "$drv" 2>/dev/null || echo "")
			log_info "[DRY-RUN] Would push: $store_path"
		else
			# Ensure it is built (should be cached from previous step)
			if ! nix build --quiet --impure --accept-flake-config "$drv" 2>/dev/null; then
				log_warn "Failed to resolve $drv, skipping push"
				continue
			fi

			local store_path
			store_path=$(nix path-info --impure --accept-flake-config "$drv" 2>/dev/null || echo "")

			if [[ -z "$store_path" ]]; then
				log_warn "Could not get store path for $drv"
				continue
			fi

			log_info "Pushing to $CACHE: $(basename "$store_path")"

			# Use authToken from env (CACHIX_AUTH_TOKEN) if set, handled by cachix CLI automatically
			if safe_exec cachix push "$CACHE" "$store_path" 2>&1 | grep -v "Compressing"; then
				log_success "Pushed $drv"
			else
				log_error "Failed to push $drv"
				# Don't exit immediately, try pushing others
			fi
		fi
	done
}

# Push ChromeOS chunk derivations (caches CDN pulls)
push_chunks() {
	local board="$1"

	log_info "Pushing ChromeOS chunk derivations for board: $board"

	# Get the realized output path of the shim derivation
	local shim_path
	shim_path=$(nix build --impure --accept-flake-config --print-out-paths \
		".#chromeos-shim-${board}" 2>/dev/null || echo "")

	if [[ -z "$shim_path" ]]; then
		log_warn "Could not build shim for chunk discovery"
		return 0
	fi

	# Push the entire closure (includes all fetched chunks)
	log_info "Pushing shim closure (includes chunks)..."
	nix-store --query --requisites "$shim_path" | cachix push "$CACHE"
}

# Main execution
main() {
	log_info "Cachix Push Tool"
	log_info "Cache: $CACHE"
	log_info "Board: $BOARD"
	log_info "Rootfs: $ROOTFS_FLAVOR"
	log_info "Drivers: $DRIVERS_MODE"

	if is_ci; then
		log_info "CI environment detected"
	fi

	# Push derivations
	if [[ "$SKIP_DERIVATIONS" -eq 0 ]]; then
		push_derivations "$BOARD"
	else
		log_info "Skipping derivation push (--skip-derivations)"
	fi

	# Push ChromeOS chunk derivations (caches CDN pulls)
	if [[ "$SKIP_CHUNKS" -eq 0 ]]; then
		push_chunks "$BOARD"
	else
		log_info "Skipping chunk push (--skip-chunks)"
	fi

	log_success "Cachix push complete"
}

main "$@"
