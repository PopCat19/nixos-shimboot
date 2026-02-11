#!/usr/bin/env fish

# Expand Root Filesystem Function
#
# Purpose: Expand root partition to full disk capacity
# Dependencies: findmnt, lsblk, blockdev, sfdisk, jq, growpart, cryptsetup, resize2fs
# Related: filesystem-helpers.nix, filesystems.nix
#
# This function:
# - Expands root partition to full disk capacity
# - Handles both encrypted and unencrypted filesystems
# - Provides interactive confirmation before disk modifications

function expand_rootfs
    set -euo pipefail

    # Colors & Logging
    set -l BOLD "\033[1m"
    set -l GREEN "\033[1;32m"
    set -l YELLOW "\033[1;33m"
    set -l RED "\033[1;31m"
    set -l BLUE "\033[1;34m"
    set -l CYAN "\033[1;36m"
    set -l NC "\033[0m"

    if set -q DEBUG
        set -x
    end

    if test (id -u) -ne 0
        echo -e "$RED[ERROR]$NC This needs to be run as root."
        exit 1
    end

    set -l root_dev (findmnt -T / -no SOURCE)
    set -l luks (echo "$root_dev" | grep "/dev/mapper" || true)

    if test -n "$luks"
        echo -e "$YELLOW[WARN]$NC Note: Root partition is encrypted."
        set -l kname_dev (lsblk --list --noheadings --paths --output KNAME "$root_dev")
        set -l kname (basename "$kname_dev")
        set -l part_dev "/dev/"(basename "/sys/class/block/$kname/slaves/"*)
    else
        set -l part_dev "$root_dev"
    end

    set -l disk_dev (lsblk --list --noheadings --paths --output PKNAME "$part_dev" | head -n1)

    set -l part_num (lsblk --list --noheadings --output MAJ:MIN "$part_dev" | awk '{print $2}')
    if string match -qr '[0-9]+$' "$part_dev"
        set -l num_match (string match -r '[0-9]+$' "$part_dev")
        set part_num "$num_match"
    end

    set -l disk_size (blockdev --getsize64 "$disk_dev")
    # Use sfdisk to get partition start sector since BusyBox blockdev doesn't support --getstart
    set -l part_start (sfdisk -J "$disk_dev" | jq -r ".partitiontable.partitions[] | select(.node == \"$part_dev\") | .start")
    set -l part_end (math (blockdev --getsize64 "$part_dev") + (blockdev --getss "$part_dev") * $part_start)
    set -l size_diff (math $disk_size - $part_end)
    set -l threshold (math $disk_size / 100)

    if test "$size_diff" -lt "$threshold"
        echo -e "$GREEN[INFO]$NC Root partition already uses the full disk space. Nothing to do."
        exit 0
    end

    echo -e "$BLUE[INFO]$NC Automatically detected root filesystem:"
    fdisk -l "$disk_dev" 2>/dev/null | grep "$disk_dev:" -A 1
    echo
    echo -e "$BLUE[INFO]$NC Automatically detected root partition:"
    fdisk -l "$disk_dev" 2>/dev/null | grep "$part_dev"
    echo
    read -p "Press enter to continue, or ctrl+c to cancel. "

    echo
    echo -e "$BLUE[INFO]$NC Before:"
    df -h /

    echo
    echo -e "$BLUE[STEP]$NC Expanding the partition and filesystem..."
    growpart "$disk_dev" "$part_num" || true
    if test -n "$luks"
        echo -e "$BLUE[STEP]$NC Resizing encrypted filesystem..."
        cryptsetup resize "$root_dev" || true
    end
    echo -e "$BLUE[STEP]$NC Resizing filesystem..."
    resize2fs "$root_dev" || true

    echo
    echo -e "$BLUE[INFO]$NC After:"
    df -h /

    echo
    echo -e "$GREEN[SUCCESS]$NC Done expanding the root filesystem."
end
