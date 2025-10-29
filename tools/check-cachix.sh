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

CACHE="shimboot-systemd-nixos"

echo "Checking Cachix cache: $CACHE"
echo

# Test connectivity
if curl -sf "https://${CACHE}.cachix.org/nix-cache-info" >/dev/null; then
    echo "✓ Cache endpoint reachable"
else
    echo "✗ Cannot reach cache endpoint"
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
echo "Checking cache coverage for board: $BOARD"
echo

for attr in "${ATTRS[@]}"; do
    printf "  %-30s ... " "$attr"
    
    # Get derivation path without building
    drv_path=$(nix eval --raw ".#${attr}" 2>/dev/null || echo "")
    
    if [ -z "$drv_path" ]; then
        echo "SKIP (not found)"
        continue
    fi
    
    # Query Cachix
    if curl -sf "https://${CACHE}.cachix.org/${drv_path}.narinfo" >/dev/null 2>&1; then
        echo "CACHED ✓"
    else
        echo "MISSING ✗"
    fi
done