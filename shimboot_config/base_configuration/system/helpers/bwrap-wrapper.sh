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
