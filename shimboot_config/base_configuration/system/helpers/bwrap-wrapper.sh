#!/usr/bin/env bash

# Bwrap Wrapper Script
#
# Purpose: Transparent wrapper that intercepts bwrap calls and converts tmpfs to bind mounts
# Dependencies: bwrap, mkdir
# Related: security.nix, bwrap-lsm-workaround.sh
#
# This script:
# - Acts as a drop-in replacement for bwrap
# - Automatically converts tmpfs mounts to bind mounts
# - Can be placed in PATH to intercept all bwrap calls
# - Provides transparent workaround for ChromeOS LSM restrictions

set -Eeuo pipefail

# Configuration
BWRAP_REAL="/run/wrappers/bin/bwrap"
BWRAP_CACHE_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/bwrap-cache"

# Create cache directory if it doesn't exist
mkdir -p "$BWRAP_CACHE_DIR"
chmod 700 "$BWRAP_CACHE_DIR"

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
