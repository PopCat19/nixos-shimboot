#!/usr/bin/env bash

# check-cachix.sh
#
# Purpose: Check Cachix cache health and coverage for shimboot derivations
#
# This module:
# - Tests cache endpoint connectivity
# - Checks cache coverage for specific board derivations
# - Reports whether derivations are cached or need building

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/logging.sh"

CACHE="shimboot-systemd-nixos"
BOARD=""
PROFILE="default"

# Parse arguments
while [[ $# -gt 0 ]]; do
	case "$1" in
	--board)
		BOARD="${2:-}"
		shift 2
		;;
	--profile)
		PROFILE="${2:-default}"
		shift 2
		;;
	-h | --help)
		echo "Usage: $0 --board BOARD [--profile PROFILE]"
		echo ""
		echo "Options:"
		echo "  --board BOARD     Target board (required)"
		echo "  --profile PROFILE Build profile (default: default)"
		exit 0
		;;
	*)
		log_error "Unknown option: $1"
		exit 1
		;;
	esac
done

# Set default board if not provided
if [ -z "$BOARD" ]; then
	BOARD="dedede"
	log_warn "No --board specified; defaulting to 'dedede'."
fi

# Validate profile exists
if [ ! -d "shimboot_config/profiles/$PROFILE" ]; then
	log_error "Profile '$PROFILE' not found in shimboot_config/profiles/"
	log_error "Available profiles: $(find shimboot_config/profiles -maxdepth 1 -mindepth 1 -type d -printf '%f\n' 2>/dev/null | tr '\n' ' ')"
	exit 1
fi

log_info "Checking Cachix cache: $CACHE"
echo

# Test connectivity
if curl -sf "https://${CACHE}.cachix.org/nix-cache-info" >/dev/null; then
	log_success "Cache endpoint reachable"
else
	log_error "Cannot reach cache endpoint"
	exit 1
fi

# Check for specific derivations
ATTRS=(
	"chromeos-shim-${BOARD}"
	"extracted-kernel-${BOARD}"
	"initramfs-patching-${BOARD}"
	"raw-rootfs-${PROFILE}"
)

echo
log_info "Checking cache coverage for board: $BOARD, profile: $PROFILE"
echo

missing=0
for attr in "${ATTRS[@]}"; do
	printf "  %-30s ... " "$attr"

	# Get store path using nix path-info
	store_path=$(nix path-info --json --impure --accept-flake-config ".#${attr}" 2>/dev/null | jq -r '.[0].path // empty' || echo "")

	if [ -z "$store_path" ]; then
		log_warn "SKIP (not found)"
		continue
	fi

	# Extract hash from store path for narinfo URL
	store_hash=$(basename "$store_path" | cut -d- -f1)

	# Query Cachix
	if curl -sf "https://${CACHE}.cachix.org/${store_hash}.narinfo" >/dev/null 2>&1; then
		log_success "CACHED"
	else
		log_error "MISSING"
		((missing++))
	fi
done

# Exit with error if any derivations are missing
if [ "$missing" -gt 0 ]; then
	exit 1
fi
