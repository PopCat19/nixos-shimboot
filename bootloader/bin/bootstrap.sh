#!/bin/busybox sh
# Copyright 2015 The Chromium OS Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#
# To bootstrap the factory installer on rootfs. This file must be executed as
# PID=1 (exec).
# Note that this script uses the busybox shell (not bash, not dash).

#original: https://chromium.googlesource.com/chromiumos/platform/initramfs/+/refs/heads/main/factory_shim/bootstrap.sh

#set -x
set +x

rescue_mode=""

invoke_terminal() {
	local tty="$1"
	local title="$2"
	shift
	shift
	# Copied from factory_installer/factory_shim_service.sh.
	echo "${title}" >>${tty}
	setsid sh -c "exec script -afqc '$*' /dev/null <${tty} >>${tty} 2>&1 &"
}

enable_debug_console() {
	local tty="$1"
	echo -e "debug console enabled on ${tty}"
	invoke_terminal "${tty}" "[Bootstrap Debug Console]" "/bin/busybox sh"
}

#get a partition block device from a disk path and a part number
get_part_dev() {
	local disk="$1"
	local partition="$2"

	#disk paths ending with a number will have a "p" before the partition number
	last_char="$(echo -n "$disk" | tail -c 1)"
	if [ "$last_char" -eq "$last_char" ] 2>/dev/null; then
		echo "${disk}p${partition}"
	else
		echo "${disk}${partition}"
	fi
}

find_rootfs_partitions() {
	local disks=$(fdisk -l | sed -n "s/Disk \(\/dev\/.*\):.*/\1/p")
	if [ ! "${disks}" ]; then
		return 1
	fi

	for disk in $disks; do
		local partitions=$(fdisk -l $disk | sed -n "s/^[ ]\+\([0-9]\+\).*shimboot_rootfs:\(.*\)$/\1:\2/p")
		if [ ! "${partitions}" ]; then
			continue
		fi
		for partition in $partitions; do
			get_part_dev "$disk" "$partition"
		done
	done
}

find_chromeos_partitions() {
	local roota_partitions="$(cgpt find -l ROOT-A)"
	local rootb_partitions="$(cgpt find -l ROOT-B)"

	if [ "$roota_partitions" ]; then
		for partition in $roota_partitions; do
			echo "${partition}:ChromeOS_ROOT-A:CrOS"
		done
	fi

	if [ "$rootb_partitions" ]; then
		for partition in $rootb_partitions; do
			echo "${partition}:ChromeOS_ROOT-B:CrOS"
		done
	fi
}

find_all_partitions() {
	echo "$(find_chromeos_partitions)"
	echo "$(find_rootfs_partitions)"
}

# locate the vendor helper partition (shimboot_rootfs:vendor or FS label shimboot_vendor)
find_vendor_partition() {
	# Prefer filesystem label first (fast path)
	if [ -e "/dev/disk/by-label/shimboot_vendor" ]; then
		# resolve symlink if possible; fall back to path
		local dev="/dev/disk/by-label/shimboot_vendor"
		echo "$dev"
		return 0
	fi

	# Guard blkid usage - not all busybox builds have full blkid support
	if command -v blkid >/dev/null 2>&1; then
		local dev_from_label="$(blkid -L shimboot_vendor 2>/dev/null || true)"
		if [ -n "$dev_from_label" ]; then
			echo "$dev_from_label"
			return 0
		fi

		# Try PARTLABEL via blkid (GPT partition name) - may not work in busybox
		local dev_from_partlabel="$(blkid -t PARTLABEL='shimboot_rootfs:vendor' -o device 2>/dev/null | head -n1 || true)"
		if [ -n "$dev_from_partlabel" ]; then
			echo "$dev_from_partlabel"
			return 0
		fi
	fi

	# cgpt label fallback (preferred on ChromeOS devices)
	if command -v cgpt >/dev/null 2>&1; then
		local p="$(cgpt find -l 'shimboot_rootfs:vendor' 2>/dev/null | head -n1)"
		if [ -n "$p" ]; then
			echo "$p"
			return 0
		fi
	fi

	# fdisk fallback (best-effort; output format varies)
	if command -v fdisk >/dev/null 2>&1; then
		local disks
		disks="$(fdisk -l 2>/dev/null | sed -n "s/Disk \(\/dev\/.*\):.*/\1/p")"
		for disk in $disks; do
			# capture the device path in the first column (e.g., /dev/sdc5) when the line contains our PARTLABEL
			local dev_guess
			dev_guess="$(fdisk -l "$disk" 2>/dev/null | sed -n "s/^[[:space:]]*\\(\/dev\/[^[:space:]]\\+\\)[[:space:]].*shimboot_rootfs:vendor.*/\\1/p" | head -n1)"
			if [ -n "$dev_guess" ]; then
				echo "$dev_guess"
				return 0
			fi
		done
	fi

	return 1
}

# mount vendor and bind its modules/firmware into the target root (no tmpfs staging)
bind_vendor_into() {
	local target_root="/newroot"
	local vendor_part="$(find_vendor_partition)"
	if [ ! "$vendor_part" ]; then
		echo "vendor: not found"
		return 0
	fi

	echo "vendor: device=${vendor_part}"
	echo "mounting vendor partition at ${target_root}/.vendor (read-only)"
	mkdir -p "${target_root}/.vendor"
	if mount -o ro "$vendor_part" "${target_root}/.vendor"; then
		echo "vendor: mounted"

		# Direct bind from vendor mount - no tmpfs staging to reduce memory pressure
		# Only bind non-empty directories to avoid masking system paths
		if [ -d "${target_root}/.vendor/lib/modules" ] && find "${target_root}/.vendor/lib/modules" -type f -name "*.ko*" 2>/dev/null | head -n1 | grep -q .; then
			echo "binding vendor modules to ${target_root}/lib/modules"
			mkdir -p "${target_root}/lib/modules"
			if mount -o bind "${target_root}/.vendor/lib/modules" "${target_root}/lib/modules"; then
				echo "vendor: modules bound successfully"
			else
				echo "vendor: failed to bind modules - skipping"
			fi
		else
			echo "vendor: no modules found or directory empty"
		fi

		if [ -d "${target_root}/.vendor/lib/firmware" ] && find "${target_root}/.vendor/lib/firmware" -type f 2>/dev/null | head -n1 | grep -q .; then
			echo "binding vendor firmware to ${target_root}/lib/firmware"
			mkdir -p "${target_root}/lib/firmware"
			if mount -o bind "${target_root}/.vendor/lib/firmware" "${target_root}/lib/firmware"; then
				echo "vendor: firmware bound successfully"
			else
				echo "vendor: failed to bind firmware - skipping"
			fi
		else
			echo "vendor: no firmware found or directory empty"
		fi

		# Keep vendor filesystem mounted - it will persist across pivot_root
		# Do not unmount vendor device as we have active bind mounts from it
		echo "vendor: keeping mounted for active bind mounts"
	else
		echo "failed to mount vendor partition at ${target_root}/.vendor"
	fi
}

#from original bootstrap.sh
move_mounts() {
	local base_mounts="/sys /proc /dev"
	local newroot_mnt="$1"
	for mnt in $base_mounts; do
		# $mnt is a full path (leading '/'), so no '/' joiner
		mkdir -p "$newroot_mnt$mnt"
		mount -n -o move "$mnt" "$newroot_mnt$mnt"
	done
}

print_license() {
	local shimboot_version="$(cat /opt/.shimboot_version)"
	if [ -f "/opt/.shimboot_version_dev" ]; then
		local git_hash="$(cat /opt/.shimboot_version_dev)"
		local suffix="-dev-$git_hash"
	fi
	cat <<EOF
Shimboot ${shimboot_version}${suffix}

ading2210/shimboot: Boot desktop Linux from a Chrome OS RMA shim.
Copyright (C) 2025 ading2210

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
EOF
}

print_selector() {
	local rootfs_partitions="$1"
	local i=1

	echo "┌──────────────────────┐"
	echo "│ Shimboot OS Selector │"
	echo "└──────────────────────┘"

	if [ "${rootfs_partitions}" ]; then
		for rootfs_partition in $rootfs_partitions; do
			#i don't know of a better way to split a string in the busybox shell
			local part_path=$(echo $rootfs_partition | cut -d ":" -f 1)
			local part_name=$(echo $rootfs_partition | cut -d ":" -f 2)
			local part_flags=$(echo $rootfs_partition | cut -d ":" -f 3)
			# hide vendor helper partition from menu
			if [ "$part_name" = "vendor" ]; then
				continue
			fi
			echo "${i}) ${part_name} on ${part_path}"
			i=$((i + 1))
		done
	else
		echo "no bootable partitions found. please see the shimboot documentation to mark a partition as bootable."
	fi

	echo "q) reboot"
	echo "s) enter a shell"
	echo "l) view license"
}

get_selection() {
	local rootfs_partitions="$1"
	local i=1

	read -p "Your selection: " selection
	if [ "$selection" = "q" ]; then
		echo "rebooting now."
		reboot -f
	elif [ "$selection" = "s" ]; then
		reset
		enable_debug_console "$TTY1"
		return 0
	elif [ "$selection" = "l" ]; then
		clear
		print_license
		echo
		read -p "press [enter] to return to the bootloader menu"
		return 1
	fi

	local selection_cmd="$(echo "$selection" | cut -d' ' -f1)"
	if [ "$selection_cmd" = "rescue" ]; then
		selection="$(echo "$selection" | cut -d' ' -f2-)"
		rescue_mode="1"
	else
		rescue_mode=""
	fi

	for rootfs_partition in $rootfs_partitions; do
		local part_path=$(echo $rootfs_partition | cut -d ":" -f 1)
		local part_name=$(echo $rootfs_partition | cut -d ":" -f 2)
		local part_flags=$(echo $rootfs_partition | cut -d ":" -f 3)

		# skip vendor helper partition from selection indices
		if [ "$part_name" = "vendor" ]; then
			continue
		fi

		if [ "$selection" = "$i" ]; then
			echo "selected $part_path"
			if [ "$part_flags" = "CrOS" ]; then
				echo "booting chrome os partition"
				print_donor_selector "$rootfs_partitions"
				get_donor_selection "$rootfs_partitions" "$part_path"
			else
				boot_target "$part_path"
			fi
			return 1
		fi

		i=$((i + 1))
	done

	echo "invalid selection"
	sleep 1
	return 1
}

copy_progress() {
	local source="$1"
	local destination="$2"
	mkdir -p "$destination"
	# Fallback to plain tar if pv is unavailable in the initramfs
	if command -v pv >/dev/null 2>&1; then
		tar -cf - -C "${source}" . | pv -f | tar -xf - -C "${destination}"
	else
		tar -cf - -C "${source}" . | tar -xf - -C "${destination}"
	fi
}

debug_dir() {
	local path="$1"
	if [ -d "$path" ]; then
		local files="$(find "$path" -type f 2>/dev/null | wc -l)"
		local size_k="$(du -sk "$path" 2>/dev/null | awk '{print $1}')"
		echo "DEBUG: $path -> files=${files} size=${size_k}K"
		# list top-level entries for quick sanity
		ls -la "$path" 2>/dev/null | head -n 20 || true
	else
		echo "DEBUG: $path (missing)"
	fi
}

print_donor_selector() {
	local rootfs_partitions="$1"
	local i=1

	echo "Choose a partition to copy firmware and modules from:"

	for rootfs_partition in $rootfs_partitions; do
		local part_path=$(echo $rootfs_partition | cut -d ":" -f 1)
		local part_name=$(echo $rootfs_partition | cut -d ":" -f 2)
		local part_flags=$(echo $rootfs_partition | cut -d ":" -f 3)

		if [ "$part_flags" = "CrOS" ]; then
			continue
		fi

		echo "${i}) ${part_name} on ${part_path}"
		i=$((i + 1))
	done
}

yes_no_prompt() {
	local prompt="$1"
	local var_name="$2"

	while true; do
		read -p "$prompt" temp_result

		if [ "$temp_result" = "y" ] || [ "$temp_result" = "n" ]; then
			#the busybox shell has no other way to declare a variable from a string
			#the declare command and printf -v are both bashisms
			eval "$var_name='$temp_result'"
			return 0
		else
			echo "invalid selection"
		fi
	done
}

get_donor_selection() {
	local rootfs_partitions="$1"
	local target="$2"
	local i=1
	read -p "Your selection: " selection

	for rootfs_partition in $rootfs_partitions; do
		local part_path=$(echo $rootfs_partition | cut -d ":" -f 1)
		local part_name=$(echo $rootfs_partition | cut -d ":" -f 2)
		local part_flags=$(echo $rootfs_partition | cut -d ":" -f 3)

		if [ "$part_flags" = "CrOS" ]; then
			continue
		fi

		if [ "$selection" = "$i" ]; then
			echo "selected $part_path as the donor partition"
			yes_no_prompt "would you like to spoof verified mode? this is useful if you're planning on using chrome os while enrolled. (y/n): " use_crossystem
			yes_no_prompt "would you like to spoof an invalid hwid? this will forcibly prevent the device from being enrolled. (y/n): " invalid_hwid
			boot_chromeos "$target" "$part_path" "$use_crossystem" "$invalid_hwid"
		fi

		i=$((i + 1))
	done

	echo "invalid selection"
	sleep 1
	return 1
}

exec_init() {
	if [ "$rescue_mode" = "1" ]; then
		echo "entering a rescue shell instead of starting init"
		echo "once you are done fixing whatever is broken, run 'exec /sbin/init' to continue booting the system normally"

		if [ -f "/bin/bash" ]; then
			exec /bin/bash <"$TTY1" >>"$TTY1" 2>&1
		else
			exec /bin/sh <"$TTY1" >>"$TTY1" 2>&1
		fi
	else
		exec /sbin/init <"$TTY1" >>"$TTY1" 2>&1
	fi
}

boot_target() {
	local target="$1"

	echo "moving mounts to newroot"
	mkdir /newroot
	#use cryptsetup to check if the rootfs is encrypted
	if [ -x "$(command -v cryptsetup)" ] && cryptsetup luksDump "$target" >/dev/null 2>&1; then
		cryptsetup open $target rootfs
		# Prefer explicit filesystem type to avoid EINVAL when fs module isn't autoloaded
		if ! mount -t ext4 /dev/mapper/rootfs /newroot 2>/dev/null; then
			# Fallback to autodetect and emit diagnostics
			if ! mount /dev/mapper/rootfs /newroot; then
				echo "mount failed for LUKS rootfs: /dev/mapper/rootfs"
				echo "Available filesystems in initramfs:"
				cat /proc/filesystems || true
				echo "blkid /dev/mapper/rootfs:"
				blkid /dev/mapper/rootfs || true
				return 1
			fi
		fi
	else
		# Non-encrypted rootfs; try ext4 explicitly first
		if ! mount -t ext4 $target /newroot 2>/dev/null; then
			# Fallback to autodetect and emit diagnostics on failure
			if ! mount $target /newroot; then
				echo "mount failed for $target"
				echo "Available filesystems in initramfs:"
				cat /proc/filesystems || true
				echo "blkid $target:"
				blkid $target || true
				return 1
			fi
		fi
	fi
	# mount vendor partition and copy modules/firmware if present
	bind_vendor_into
	#bind mount /dev/console to show systemd boot msgs
	if [ -f "/bin/frecon-lite" ]; then
		rm -f /dev/console
		touch /dev/console #this has to be a regular file otherwise the system crashes afterwards
		mount -o bind "$TTY1" /dev/console
	fi
	move_mounts /newroot

	echo "switching root"
	mkdir -p /newroot/bootloader
	pivot_root /newroot /newroot/bootloader
	exec_init
}

boot_chromeos() {
	local target="$1"
	local donor="$2"
	local use_crossystem="$3"
	local invalid_hwid="$4"

	echo "mounting target"
	mkdir /newroot
	mount -o ro $target /newroot

	echo "mounting tmpfs"
	mount -t tmpfs -o mode=1777 none /newroot/tmp
	mount -t tmpfs -o mode=0555 run /newroot/run
	mkdir -p -m 0755 /newroot/run/lock

	echo "mounting donor partition: $donor"
	local donor_mount="/newroot/tmp/donor_mnt"
	local donor_files="/newroot/tmp/donor"
	mkdir -p $donor_mount
	donor_label="$(blkid -o value -s LABEL "$donor" 2>/dev/null || true)"
	echo "donor: device=$donor label=${donor_label:-N/A}"
	mount -o ro $donor $donor_mount
	echo "donor: mounted at $donor_mount"
	debug_dir "$donor_mount/lib/modules"
	debug_dir "$donor_mount/lib/firmware"

	# Safely handle missing directories on donor (e.g., vendor may be empty)
	mkdir -p "$donor_files"
	echo "preparing donor drivers from $donor_mount"
	if [ -d "$donor_mount/lib/modules" ] || [ -d "$donor_mount/lib/firmware" ]; then
		mkdir -p "$donor_files/lib/modules" "$donor_files/lib/firmware"

		# Always copy donor modules when present (no version gating)
		if [ -d "$donor_mount/lib/modules" ]; then
			echo "copying modules to tmpfs (may take a while)"
			debug_dir "$donor_mount/lib/modules"
			mkdir -p "$donor_files/lib/modules"
			if ! copy_progress "$donor_mount/lib/modules" "$donor_files/lib/modules" 2>/dev/null; then
				cp -a "$donor_mount/lib/modules/." "$donor_files/lib/modules/" 2>/dev/null || true
			fi
			sync
			echo "donor: modules staged"
			debug_dir "$donor_files/lib/modules"
		else
			echo "no modules directory in donor; skipping modules copy"
		fi

		if [ -d "$donor_mount/lib/firmware" ]; then
			echo "copying firmware to tmpfs (may take a while)"
			debug_dir "$donor_mount/lib/firmware"
			mkdir -p "$donor_files/lib/firmware"
			if ! copy_progress "$donor_mount/lib/firmware" "$donor_files/lib/firmware" 2>/dev/null; then
				cp -a "$donor_mount/lib/firmware/." "$donor_files/lib/firmware/" 2>/dev/null || true
			fi
			sync
			echo "donor: firmware staged"
			debug_dir "$donor_files/lib/firmware"
		else
			echo "no firmware directory in donor; skipping firmware copy"
		fi

		# For vendor donor, copy into /newroot; otherwise bind if non-empty
		donor_is_vendor=""
		# Detect by filesystem label first (robust even if path differs)
		if blkid -o value -s LABEL "$donor" 2>/dev/null | grep -qx "shimboot_vendor"; then
			donor_is_vendor="1"
		else
			# Fallback: compare against discovered vendor device path
			vp="$(blkid -L shimboot_vendor 2>/dev/null || find_vendor_partition 2>/dev/null || true)"
			if [ -n "$vp" ] && [ "$donor" = "$vp" ]; then
				donor_is_vendor="1"
			fi
		fi

		# Use bind mounts for both vendor and regular donors to avoid writing to read-only ChromeOS roots
		# Bind only if non-empty to avoid masking system paths with empty dirs
		if [ -d "$donor_files/lib/modules" ] && ls -1 "$donor_files/lib/modules" 2>/dev/null | grep -q .; then
			echo "binding donor modules to /newroot/lib/modules"
			mkdir -p /newroot/lib/modules
			mount -o bind "$donor_files/lib/modules" /newroot/lib/modules
		fi
		if [ -d "$donor_files/lib/firmware" ] && ls -1 "$donor_files/lib/firmware" 2>/dev/null | grep -q .; then
			echo "binding donor firmware to /newroot/lib/firmware"
			mkdir -p /newroot/lib/firmware
			mount -o bind "$donor_files/lib/firmware" /newroot/lib/firmware
		fi
	else
		echo "donor has no lib/modules or lib/firmware; skipping driver bind"
	fi

	umount $donor_mount
	rm -rf $donor_mount

	if [ -e "/newroot/etc/init/tpm-probe.conf" ]; then
		echo "applying chrome os flex patches"
		mkdir -p /newroot/tmp/empty
		mount -o bind /newroot/tmp/empty /sys/class/tpm

		cat /newroot/etc/lsb-release | sed "s/DEVICETYPE=OTHER/DEVICETYPE=CHROMEBOOK/" >/newroot/tmp/lsb-release
		mount -o bind /newroot/tmp/lsb-release /newroot/etc/lsb-release
	fi

	echo "patching chrome os rootfs"
	cat /newroot/etc/ui_use_flags.txt | sed "/reven_branding/d" | sed "/os_install_service/d" >/newroot/tmp/ui_use_flags.txt
	mount -o bind /newroot/tmp/ui_use_flags.txt /newroot/etc/ui_use_flags.txt

	cp /opt/mount-encrypted /newroot/tmp/mount-encrypted
	cp /newroot/usr/sbin/mount-encrypted /newroot/tmp/mount-encrypted.real
	mount -o bind /newroot/tmp/mount-encrypted /newroot/usr/sbin/mount-encrypted

	cat /newroot/etc/init/boot-splash.conf | sed '/^script$/a \  pkill frecon-lite || true' >/newroot/tmp/boot-splash.conf
	mount -o bind /newroot/tmp/boot-splash.conf /newroot/etc/init/boot-splash.conf

	if [ "$use_crossystem" = "y" ]; then
		echo "patching crossystem"
		cp /opt/crossystem /newroot/tmp/crossystem
		if [ "$invalid_hwid" = "y" ]; then
			sed -i 's/block_devmode/hwid/' /newroot/tmp/crossystem
		fi

		cp /newroot/usr/bin/crossystem /newroot/tmp/crossystem_old
		mount -o bind /newroot/tmp/crossystem /newroot/usr/bin/crossystem
	fi

	echo "moving mounts"
	move_mounts /newroot

	echo "switching root"
	mkdir -p /newroot/tmp/bootloader
	pivot_root /newroot /newroot/tmp/bootloader

	echo "starting init"
	exec_init
}

main() {
	echo "starting the shimboot bootloader"

	enable_debug_console "$TTY2"

	local valid_partitions="$(find_all_partitions)"

	while true; do
		clear
		print_selector "${valid_partitions}"

		if get_selection "${valid_partitions}"; then
			break
		fi
	done
}

trap - EXIT
main "$@"
sleep 1d
