#!/usr/bin/env bash

# Check Cachix Cache Health Script
#
# Purpose: Check Cachix cache health and coverage for shimboot derivations
# Dependencies: curl, nix
# Related: assemble-final.sh, flake_modules/cachix-config.nix
#
# This script checks:
# - Cache endpoint connectivity
# - Cache coverage for specific board derivations
# - Whether derivations are available in the cache or need to be built
#
# Usage:
#   ./tools/check-cachix.sh [BOARD]
#
# Examples:
#   ./tools/check-cachix.sh dedede
#   ./tools/check-cachix.sh octopus

set -euo pipefail

# Colors & Logging
ANSI_CLEAR='\033[0m'
ANSI_BOLD='\033[1m'
ANSI_GREEN='\033[1;32m'
ANSI_BLUE='\033[1;34m'
ANSI_YELLOW='\033[1;33m'
ANSI_RED='\033[1;31m'

log_info() { printf "${ANSI_BLUE}[INFO]${ANSI_CLEAR} %s\n" "$*"; }
log_success() { printf "${ANSI_GREEN}[SUCCESS]${ANSI_CLEAR} %s\n" "$*"; }
log_warn() { printf "${ANSI_YELLOW}[WARN]${ANSI_CLEAR} %s\n" "$*"; }
log_error() { printf "${ANSI_RED}[ERROR]${ANSI_CLEAR} %s\n" "$*"; }

CACHE="shimboot-systemd-nixos"

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
BOARD="${1:-dedede}"
ATTRS=(
	"chromeos-shim-${BOARD}"
	"extracted-kernel-${BOARD}"
	"initramfs-patching-${BOARD}"
	"raw-rootfs"
)

echo
log_info "Checking cache coverage for board: $BOARD"
echo

for attr in "${ATTRS[@]}"; do
	printf "  %-30s ... " "$attr"

	# Get derivation path without building
	drv_path=$(nix eval --raw ".#${attr}" 2>/dev/null || echo "")

	if [ -z "$drv_path" ]; then
		log_warn "SKIP (not found)"
		continue
	fi

	# Query Cachix
	if curl -sf "https://${CACHE}.cachix.org/${drv_path}.narinfo" >/dev/null 2>&1; then
		log_success "CACHED"
	else
		log_error "MISSING"
	fi
done
