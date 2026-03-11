#!/usr/bin/env bash

# push-to-cachix.sh
#
# Purpose: Push Nix derivations to Cachix binary cache
#
# This module:
# - Pushes runtime derivations (systemd, noctalia, kernel)
# - Excludes build artifacts (shim, recovery, initramfs) - too large or available elsewhere
# - Supports dry-run and selective rootfs push

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/logging.sh"
source "${SCRIPT_DIR}/../lib/runtime.sh"

# Configuration
CACHE="shimboot-systemd-nixos"
BOARD=""
ROOTFS_FLAVOR="full"
SKIP_ROOTFS=0
DRY_RUN=0

usage() {
	cat <<'EOF'
Usage: push-to-cachix.sh --board BOARD [OPTIONS]

Options:
    --board BOARD              Target board (required)
    --rootfs FLAVOR            Rootfs variant (full, minimal)
    --skip-rootfs              Skip pushing rootfs (large, often cached elsewhere)
    --dry-run                  Show what would be done

Examples:
    # Push systemd, noctalia, kernel for board
    ./tools/build/push-to-cachix.sh --board dedede

    # Push with rootfs (large, optional)
    ./tools/build/push-to-cachix.sh --board dedede
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
	--skip-rootfs)
		SKIP_ROOTFS=1
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

# Push Nix derivations (excluding large images like shim/recovery)
push_derivations() {
	local board="$1"
	local rootfs_attr="raw-rootfs"

	if [[ "$ROOTFS_FLAVOR" == "minimal" ]]; then
		rootfs_attr="raw-rootfs-minimal"
	fi

	log_info "Pushing Nix derivations for board: $board"

	# Push runtime derivations not on Hydra
	# Available: systemd, noctalia, zen, extracted-kernel-*
	# Excluded: shim, recovery, initramfs (too large or available elsewhere)
	local derivations=(
		".#packages.x86_64-linux.systemd"
		".#packages.x86_64-linux.noctalia"
		".#packages.x86_64-linux.zen"
		".#extracted-kernel-${board}"
	)

	# Add rootfs only if not skipped
	if [[ "$SKIP_ROOTFS" -eq 0 ]]; then
		derivations+=(".#${rootfs_attr}")
	fi

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
			# Try to get existing store path without building (may already be cached)
			local store_path
			store_path=$(nix path-info --impure --accept-flake-config "$drv" 2>/dev/null || echo "")

			# If not cached, try building
			if [[ -z "$store_path" ]]; then
				if ! nix build --quiet --impure --accept-flake-config "$drv" 2>/dev/null; then
					log_warn "Failed to resolve $drv, skipping push"
					continue
				fi
				store_path=$(nix path-info --impure --accept-flake-config "$drv" 2>/dev/null || echo "")
			fi

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
# DISABLED: Large downloads, typically not needed as CDN is fast
push_chunks() {
	local board="$1"

	log_info "ChromeOS chunk pushing disabled (use --skip-chunks if flag exists)"
	log_info "CDN pulls are typically fast enough; chunks are large"
}

# Main execution
main() {
	log_info "Cachix Push Tool"
	log_info "Cache: $CACHE"
	log_info "Board: $BOARD"
	log_info "Rootfs: $ROOTFS_FLAVOR (skip: $SKIP_ROOTFS)"

	if is_ci; then
		log_info "CI environment detected"
	fi

	# Push runtime derivations (kernel, optional rootfs)
	push_derivations "$BOARD"

	log_success "Cachix push complete"
}

main "$@"
