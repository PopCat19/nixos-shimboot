#!/usr/bin/env bash
# detect.sh
#
# Purpose: Auto-detect and validate NixOS shimboot partitions.
#
# This module:
# - Scans for shimboot_rootfs:* partition labels
# - Validates partitions by checking for NixOS directory structure
# - Lists available partitions for manual selection

source "${BASH_SOURCE[0]%/*}/common.sh"

detect_partition() {
	log_info "Auto-detecting NixOS shimboot partitions..."

	local found_partitions=()

	# Scan for shimboot_rootfs:* partitions
	for part in /dev/sd[a-z][0-9] /dev/nvme[0-9]n1p[0-9]; do
		[[ -b "$part" ]] || continue

		local label
		label="$(lsblk -no PARTLABEL "$part" 2>/dev/null || true)"

		if [[ "$label" == shimboot_rootfs:* ]]; then
			found_partitions+=("$part|$label")
		fi
	done

	if [[ ${#found_partitions[@]} -eq 0 ]]; then
		log_error "No shimboot partitions found"
		list_available_partitions
		return 1
	fi

	# If only one found, validate and use it
	if [[ ${#found_partitions[@]} -eq 1 ]]; then
		local part_label="${found_partitions[0]}"
		local part="${part_label%%|*}"
		local label="${part_label##*|}"

		if validate_partition "$part"; then
			# shellcheck disable=SC2034 # Global state set for use by other modules
			TARGET_PARTITION="$part"
			log_success "Auto-detected: $part ($label)"
			return 0
		else
			log_error "Partition validation failed for $part"
			return 1
		fi
	fi

	# Multiple found - let user select
	log_info "Found ${#found_partitions[@]} shimboot partitions:"
	local options=()
	for entry in "${found_partitions[@]}"; do
		local part="${entry%%|*}"
		local label="${entry##*|}"
		local size
		size="$(lsblk -no SIZE "$part" 2>/dev/null || echo "unknown")"
		options+=("$part ($size, $label)")
	done

	local choice
	choice=$(gum choose "${options[@]}" --header "Select target partition:" --height 10)
	[[ -z "$choice" ]] && return 1

	# shellcheck disable=SC2034 # Global state set for use by other modules
	TARGET_PARTITION="${choice%% (*}"
	return 0
}

validate_partition() {
	local part="$1"

	# Check block device exists
	if [[ ! -b "$part" ]]; then
		log_error "Not a block device: $part"
		return 1
	fi

	# Check if already mounted and offer to unmount
	if findmnt -rno TARGET "$part" &>/dev/null; then
		log_warn "Partition $part is already mounted"
		if ! unmount_partition "$part"; then
			log_error "Cannot proceed with mounted partition"
			return 1
		fi
	fi

	# Try to mount and check for NixOS structure
	local temp_mnt
	temp_mnt="$(mktemp -d)"

	if ! mount -o ro "$part" "$temp_mnt" 2>/dev/null; then
		log_warn "Cannot mount $part for validation"
		rmdir "$temp_mnt" 2>/dev/null || true
		return 1
	fi

	local is_valid=0
	if [[ -d "$temp_mnt/nix" && -d "$temp_mnt/etc/nixos" ]]; then
		is_valid=1
	fi

	umount "$temp_mnt" 2>/dev/null || true
	rmdir "$temp_mnt" 2>/dev/null || true

	if [[ "$is_valid" -eq 1 ]]; then
		return 0
	else
		log_warn "Partition does not contain NixOS structure"
		return 1
	fi
}

list_available_partitions() {
	log_info "Available partitions:"
	lsblk -o NAME,SIZE,PARTLABEL,MOUNTPOINT | grep -E "part|disk" || true
}

select_partition_manually() {
	local partitions=()

	# Collect all partitions
	for part in /dev/sd[a-z][0-9] /dev/nvme[0-9]n1p[0-9]; do
		[[ -b "$part" ]] || continue
		local label size
		label="$(lsblk -no PARTLABEL "$part" 2>/dev/null || echo "unnamed")"
		size="$(lsblk -no SIZE "$part" 2>/dev/null || echo "unknown")"
		partitions+=("$part ($size, $label)")
	done

	if [[ ${#partitions[@]} -eq 0 ]]; then
		log_error "No partitions found"
		return 1
	fi

	local choice
	choice=$(gum choose "${partitions[@]}" --header "Select partition manually:" --height 15)
	[[ -z "$choice" ]] && return 1

	# shellcheck disable=SC2034 # Global state set for use by other modules
	TARGET_PARTITION="${choice%% (*}"
	return 0
}

check_partition_mounted() {
	local part="$1"
	local mps
	mps="$(lsblk -no MOUNTPOINT "$part" 2>/dev/null | sed '/^$/d' || true)"

	if [[ -n "$mps" ]]; then
		log_warn "Device $part is currently mounted at:"
		echo "$mps"
		return 0
	fi
	return 1
}

unmount_partition() {
	local part="$1"
	local mps
	mps="$(lsblk -no MOUNTPOINT "$part" 2>/dev/null | sed '/^$/d' || true)"

	if [[ -z "$mps" ]]; then
		return 0
	fi

	if gum confirm "Unmount $part before continuing?" --default=true; then
		# Try udisksctl first (preferred for UDisks-mounted partitions)
		if command -v udisksctl &>/dev/null; then
			log_info "Unmounting $part via udisksctl..."
			if udisksctl unmount -b "$part" 2>/dev/null; then
				log_success "Unmounted $part"
				return 0
			fi
		fi

		# Fallback to regular umount
		while IFS= read -r mp; do
			[[ -z "$mp" ]] && continue
			log_info "Unmounting $mp..."
			umount "$mp" 2>/dev/null || {
				log_warn "Failed to unmount $mp automatically"
				return 1
			}
		done <<<"$mps"

		# Verify unmounted
		if lsblk -no MOUNTPOINT "$part" 2>/dev/null | grep -q '\S'; then
			log_error "Device still mounted"
			return 1
		fi

		log_success "Unmounted $part"
		return 0
	else
		return 1
	fi
}
