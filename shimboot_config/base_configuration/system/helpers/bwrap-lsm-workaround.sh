#!/usr/bin/env bash

# Bwrap LSM Workaround Script
#
# Purpose: Wrapper for bwrap that converts tmpfs mounts to bind mounts
# Dependencies: bwrap, mkdir, mount
# Related: security.nix, fix-steam-bwrap.sh
#
# This script:
# - Wraps bwrap to work around ChromeOS LSM restrictions
# - Converts tmpfs mounts to bind mounts (which are allowed)
# - Maintains sandboxing functionality while avoiding LSM blocks
# - Supports both direct execution and as a drop-in replacement

set -Eeuo pipefail

# Configuration
BWRAP_REAL="/run/wrappers/bin/bwrap"
BWRAP_CACHE_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/bwrap-cache"
mkdir -p "$BWRAP_CACHE_DIR"

# Parse arguments and convert tmpfs to bind mounts
args=()
skip_next=false
tmpfs_count=0

for arg in "$@"; do
	if [[ "$skip_next" == "true" ]]; then
		skip_next=false
		continue
	fi

	# Convert --tmpfs to --bind with a cache directory
	if [[ "$arg" == "--tmpfs" ]]; then
		# Create a unique directory for this tmpfs mount
		tmpfs_dir="${BWRAP_CACHE_DIR}/tmpfs-${tmpfs_count}"
		mkdir -p "$tmpfs_dir"
		chmod 700 "$tmpfs_dir"

		# Use bind mount instead of tmpfs
		args+=("--bind" "$tmpfs_dir")
		tmpfs_count=$((tmpfs_count + 1))

		# Skip the next argument (the mount point)
		skip_next=true
		continue
	fi

	# Pass through all other arguments
	args+=("$arg")
done

# Execute the real bwrap with modified arguments
exec "$BWRAP_REAL" "${args[@]}"
