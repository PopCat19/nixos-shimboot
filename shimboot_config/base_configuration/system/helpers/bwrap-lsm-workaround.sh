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
tmpfs_count=0

for ((i = 1; i <= $#; i++)); do
	arg="${!i}"

	# Convert --tmpfs to --bind with a cache directory
	if [[ "$arg" == "--tmpfs" ]]; then
		# Create a unique directory for this tmpfs mount
		tmpfs_dir="${BWRAP_CACHE_DIR}/tmpfs-${tmpfs_count}"
		mkdir -p "$tmpfs_dir"
		chmod 700 "$tmpfs_dir"

		# Next arg is the mount point destination
		mount_point_idx=$((i + 1))
		mount_point="${!mount_point_idx}"

		# Use bind mount instead of tmpfs — needs source + destination
		args+=("--bind" "$tmpfs_dir" "$mount_point")
		tmpfs_count=$((tmpfs_count + 1))

		# Skip the mount point arg
		((i++))
		continue
	fi

	# Pass through all other arguments
	args+=("$arg")
done

# Execute the real bwrap with modified arguments
exec "$BWRAP_REAL" "${args[@]}"
