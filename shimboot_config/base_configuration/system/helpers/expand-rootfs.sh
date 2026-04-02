#!/usr/bin/env bash

# Expand Root Filesystem Script
#
# Purpose: Expand root partition to full disk capacity
# Dependencies: findmnt, lsblk, blockdev, sfdisk, jq, growpart, cryptsetup, resize2fs
# Related: filesystem-helpers.nix, filesystems.nix
#
# This script:
# - Expands root partition to full disk capacity
# - Handles both encrypted and unencrypted filesystems
# - Provides interactive confirmation before disk modifications

set -Eeuo pipefail

# Colors & Logging
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
BLUE='\033[1;34m'
NC='\033[0m'

if [[ -n "${DEBUG:-}" ]] && [[ "${DEBUG}" == "true" ]]; then
	set -x
fi

if [[ $EUID -ne 0 ]]; then
	echo -e "${RED}[ERROR]${NC} This needs to be run as root."
	exit 1
fi

root_dev=$(findmnt -T / -no SOURCE)
luks=""
part_dev=""

if [[ "$root_dev" == /dev/mapper/* ]]; then
	luks="yes"
	echo -e "${YELLOW}[WARN]${NC} Note: Root partition is encrypted."
	kname_dev=$(lsblk --list --noheadings --paths --output KNAME "$root_dev")
	kname=$(basename "$kname_dev")
	# shellcheck disable=SC2012
	slave=$(ls "/sys/class/block/${kname}/slaves/" 2>/dev/null | head -n1)
	if [[ -n "$slave" ]]; then
		part_dev="/dev/${slave}"
	else
		echo -e "${RED}[ERROR]${NC} Could not find underlying device for LUKS"
		exit 1
	fi
else
	part_dev="$root_dev"
fi

disk_dev=$(lsblk --list --noheadings --paths --output PKNAME "$part_dev" | head -n1)

# Extract trailing partition number from device path (e.g. /dev/sda3 → 3)
part_num=$(grep -oE '[0-9]+$' <<<"$part_dev" || true)
if [[ -z "$part_num" ]]; then
	# Fallback: derive from MAJ:MIN (minor number is partition index on some drivers)
	part_num=$(lsblk --list --noheadings --output MAJ:MIN "$part_dev" | awk -F: '{print $2}')
fi

disk_size=$(blockdev --getsize64 "$disk_dev")
part_size=$(blockdev --getsize64 "$part_dev")
sector_size=$(blockdev --getss "$part_dev")
part_start=$(sfdisk -J "$disk_dev" | jq -r ".partitiontable.partitions[] | select(.node == \"$part_dev\") | .start")
# part_end in bytes = start_offset_in_bytes + partition_size_in_bytes
part_end=$((sector_size * part_start + part_size))
size_diff=$((disk_size - part_end))
threshold=$((disk_size / 100))

if [[ "$size_diff" -lt "$threshold" ]]; then
	echo -e "${GREEN}[INFO]${NC} Root partition already uses the full disk space. Nothing to do."
	exit 0
fi

echo -e "${BLUE}[INFO]${NC} Automatically detected root filesystem:"
fdisk -l "$disk_dev" 2>/dev/null | grep "$disk_dev:" -A 1
echo
echo -e "${BLUE}[INFO]${NC} Automatically detected root partition:"
fdisk -l "$disk_dev" 2>/dev/null | grep "$part_dev"
echo
read -r -p "Press enter to continue, or ctrl+c to cancel: " _discard

echo
echo -e "${BLUE}[INFO]${NC} Before:"
df -h /

echo
echo -e "${BLUE}[STEP]${NC} Expanding the partition and filesystem..."
growpart "$disk_dev" "$part_num" || true
if [[ -n "$luks" ]]; then
	echo -e "${BLUE}[STEP]${NC} Resizing encrypted filesystem..."
	cryptsetup resize "$root_dev" || true
fi
echo -e "${BLUE}[STEP]${NC} Resizing filesystem..."
resize2fs "$root_dev" || true

echo
echo -e "${BLUE}[INFO]${NC} After:"
df -h /

echo
echo -e "${GREEN}[SUCCESS]${NC} Done expanding the root filesystem."
