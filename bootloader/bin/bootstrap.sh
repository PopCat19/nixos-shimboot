#!/bin/busybox sh

# bootstrap.sh
#
# Purpose: Provide interactive bootloader menu for shimboot devices with NixOS generation support.
#
# This module:
# - Detect and display bootable shimboot_rootfs partitions
# - Show RTC time and battery SoC in selector header
# - Provide NixOS generation selection when NixOS rootfs detected
# - Support set-default-generation and return-to-menu flows
# - Handle LUKS2 encrypted root filesystems via cryptsetup
# - Integrate vendor firmware and kernel modules through bind mounting
# - Execute pivot_root to transition to selected OS as PID 1

# Runs as PID 1 in initramfs using busybox shell.
# Absolute symlinks on mounted filesystems resolve from namespace root, not
# mount point. Generation listing resolves them manually via readlink.
# NixOS detection uses /nix/var/nix/profiles/system symlink, not numbered
# generation links. Numbered links (system-N-link) are created by nixos-rebuild
# at runtime; a freshly assembled image only has the bare 'system' symlink.

#original: https://chromium.googlesource.com/chromiumos/platform/initramfs/+/refs/heads/main/factory_shim/bootstrap.sh

set +x

rescue_mode=""
INIT_PATH="/sbin/init"

NIXOS_DEFAULT_GEN=""

invoke_terminal() {
	local tty="$1"
	local title="$2"
	shift
	shift
	echo "${title}" >>${tty}
	setsid sh -c "exec script -afqc '$*' /dev/null <${tty} >>${tty} 2>&1 &"
}

enable_debug_console() {
	local tty="$1"
	echo -e "debug console enabled on ${tty}"
	invoke_terminal "${tty}" "[Bootstrap Debug Console]" "/bin/busybox sh"
}

get_part_dev() {
	local disk="$1"
	local partition="$2"
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

find_vendor_partition() {
	if [ -e "/dev/disk/by-label/shimboot_vendor" ]; then
		local dev="/dev/disk/by-label/shimboot_vendor"
		echo "$dev"
		return 0
	fi

	if command -v blkid >/dev/null 2>&1; then
		local dev_from_label="$(blkid -L shimboot_vendor 2>/dev/null || true)"
		if [ -n "$dev_from_label" ]; then
			echo "$dev_from_label"
			return 0
		fi

		local dev_from_partlabel="$(blkid -t PARTLABEL='shimboot_rootfs:vendor' -o device 2>/dev/null | head -n1 || true)"
		if [ -n "$dev_from_partlabel" ]; then
			echo "$dev_from_partlabel"
			return 0
		fi
	fi

	if command -v cgpt >/dev/null 2>&1; then
		local p="$(cgpt find -l 'shimboot_rootfs:vendor' 2>/dev/null | head -n1)"
		if [ -n "$p" ]; then
			echo "$p"
			return 0
		fi
	fi

	if command -v fdisk >/dev/null 2>&1; then
		local disks
		disks="$(fdisk -l 2>/dev/null | sed -n "s/Disk \(\/dev\/.*\):.*/\1/p")"
		for disk in $disks; do
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

bind_vendor_into() {
	local target_root="/newroot"
	local vendor_part="$(find_vendor_partition)"
	if [ ! "$vendor_part" ]; then
		echo "vendor: not found"
		return 0
	fi

	echo "vendor: device=${vendor_part}"
	mkdir -p "${target_root}/.vendor"
	if mount -o ro "$vendor_part" "${target_root}/.vendor"; then
		echo "vendor: mounted"

		if [ -d "${target_root}/.vendor/lib/modules" ] && find "${target_root}/.vendor/lib/modules" -type f -name "*.ko*" 2>/dev/null | head -n1 | grep -q .; then
			mkdir -p "${target_root}/lib/modules"
			if mount -o bind "${target_root}/.vendor/lib/modules" "${target_root}/lib/modules"; then
				echo "vendor: modules bound"
			else
				echo "vendor: failed to bind modules"
			fi
		fi

		if [ -d "${target_root}/.vendor/lib/firmware" ] && find "${target_root}/.vendor/lib/firmware" -type f 2>/dev/null | head -n1 | grep -q .; then
			mkdir -p "${target_root}/lib/firmware"
			if mount -o bind "${target_root}/.vendor/lib/firmware" "${target_root}/lib/firmware"; then
				echo "vendor: firmware bound"
			else
				echo "vendor: failed to bind firmware"
			fi
		fi

		echo "vendor: keeping mounted for active bind mounts"
	else
		echo "vendor: mount failed"
	fi
}

move_mounts() {
	local base_mounts="/sys /proc /dev"
	local newroot_mnt="$1"
	for mnt in $base_mounts; do
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

# Returns true (0) if the mounted root at $1 is a NixOS system.
# Checks for the bare 'system' profile symlink, which is always present
# on a NixOS installation regardless of whether numbered generation links exist.
is_nixos_root() {
	local root="$1"
	[ -L "${root}/nix/var/nix/profiles/system" ]
}

read_rtc_time() {
	if [ -r /sys/class/rtc/rtc0/time ] && [ -r /sys/class/rtc/rtc0/date ]; then
		printf "%s %s UTC" \
			"$(cat /sys/class/rtc/rtc0/date)" \
			"$(cat /sys/class/rtc/rtc0/time)"
	elif command -v hwclock >/dev/null 2>&1; then
		hwclock -r 2>/dev/null | cut -d' ' -f1-2 || echo "unknown"
	else
		echo "unknown"
	fi
}

read_battery_soc() {
	local soc_file=""
	for f in /sys/class/power_supply/*/capacity; do
		# skip AC adapters — only battery nodes have a capacity file
		local type_file="${f%capacity}type"
		if [ -f "$type_file" ] && grep -qi "battery" "$type_file" 2>/dev/null; then
			soc_file="$f"
			break
		fi
	done
	if [ -n "$soc_file" ] && [ -r "$soc_file" ]; then
		printf "%s%%" "$(cat "$soc_file")"
	else
		echo "unknown"
	fi
}

read_default_gen() {
	local cfg="/proc/cmdline"
	if grep -q "shimboot_default_gen=" "$cfg" 2>/dev/null; then
		grep -o "shimboot_default_gen=[^ ]*" "$cfg" | cut -d= -f2
	else
		echo ""
	fi
}

# output format per line: gen_number:version:build_date:post_pivot_init_path
# Falls back to a synthetic generation-0 entry from the bare 'system' symlink
# when no numbered system-N-link profiles exist (fresh image, pre-nixos-rebuild).
# Absolute symlinks on mounted fs resolve from namespace root, not mount point;
# readlink + manual prepend required to read generation metadata pre-pivot.
list_nixos_generations() {
	local root="$1"
	local profiles_dir="${root}/nix/var/nix/profiles"
	local out=""

	for link in "${profiles_dir}"/system-*-link; do
		[ -L "$link" ] || continue

		local gen_num
		gen_num="$(basename "$link" | sed 's/system-\([0-9]*\)-link/\1/')"

		local link_target
		link_target="$(readlink "$link")"
		local resolved="${root}${link_target}"

		local version="unknown"
		if [ -f "${resolved}/nixos-version" ]; then
			version="$(cat "${resolved}/nixos-version")"
		fi

		# symlink mtime = when nixos-rebuild switch created this generation
		local build_date="unknown"
		build_date="$(stat -c '%y' "$link" 2>/dev/null | cut -d' ' -f1)" || build_date="unknown"

		out="${out}${gen_num}:${version}:${build_date}:/nix/var/nix/profiles/$(basename "$link")/init
"
	done

	if [ -z "$out" ] && [ -L "${profiles_dir}/system" ]; then
		local link_target
		link_target="$(readlink "${profiles_dir}/system")"
		local resolved="${root}${link_target}"

		local version="unknown"
		if [ -f "${resolved}/nixos-version" ]; then
			version="$(cat "${resolved}/nixos-version")"
		fi

		local build_date="unknown"
		build_date="$(stat -c '%y' "${profiles_dir}/system" 2>/dev/null | cut -d' ' -f1)" || build_date="unknown"

		echo "0:${version}:${build_date}:/nix/var/nix/profiles/system/init"
		return 0
	fi

	echo "$out" | sort -t: -k1 -n -r
}

save_default_gen() {
	local gen="$1"
	local root="$2"
	local grub_env="${root}/boot/grub/grubenv"
	local sd_loader="${root}/boot/loader/entries"

	NIXOS_DEFAULT_GEN="$gen"
	echo "default gen set to ${gen} (session only; persistent storage not available in initramfs)"
}

# Sets global INIT_PATH to the selected generation init.
select_nixos_generation() {
	local root="$1"
	local auto="${2:-0}"
	local generations
	generations="$(list_nixos_generations "$root")"

	if [ -z "$generations" ]; then
		return 1
	fi

	local gen_count
	gen_count="$(echo "$generations" | grep -c .)"

	local cmdline_default
	cmdline_default="$(read_default_gen)"
	local effective_default
	if [ -n "$NIXOS_DEFAULT_GEN" ]; then
		effective_default="$NIXOS_DEFAULT_GEN"
	elif [ -n "$cmdline_default" ]; then
		effective_default="$cmdline_default"
	else
		effective_default="$(echo "$generations" | head -n1 | cut -d: -f1)"
	fi

	if [ "$gen_count" -eq 1 ]; then
		local only_num only_ver only_date only_path
		only_num="$(echo "$generations" | cut -d: -f1)"
		only_ver="$(echo "$generations" | cut -d: -f2)"
		only_date="$(echo "$generations" | cut -d: -f3)"
		only_path="$(echo "$generations" | cut -d: -f4)"
		echo "NixOS: auto-selecting generation ${only_num} (${only_ver}, ${only_date})"
		INIT_PATH="${only_path}"
		return 0
	fi

	echo ""
	echo "NixOS generations (default: ${effective_default}):"
	echo ""

	echo "$generations" | awk -F: -v def="$effective_default" '{
		suffix = ($1 == def) ? " *" : ""
		printf "  gen %-4s  %s  %s  %s%s\n", $1, $3, $4, $2, suffix
	}'

	echo ""
	echo "  enter) boot default (gen ${effective_default})"
	echo "  d<N>)  set gen N as default for this session"
	echo "  m)     return to main menu"
	echo ""
	read -p "Generation number: " gen_sel

	case "$gen_sel" in
		m|M)
			return 2
			;;
		d[0-9]*)
			local new_def="${gen_sel#d}"
			local check_line
			check_line="$(echo "$generations" | awk -F: -v g="$new_def" '$1 == g {print; exit}')"
			if [ -n "$check_line" ]; then
				save_default_gen "$new_def" "$root"
				echo "default set to generation ${new_def}"
			else
				echo "generation ${new_def} not found"
			fi
			sleep 1
			select_nixos_generation "$root" "$auto"
			return $?
			;;
	esac

	case "$gen_sel" in
		''|*[!0-9]*) gen_sel="$effective_default" ;;
	esac

	local selected_line
	selected_line="$(echo "$generations" | awk -F: -v g="$gen_sel" '$1 == g {print; exit}')"

	if [ -z "$selected_line" ]; then
		echo "generation ${gen_sel} not found, defaulting to latest"
		selected_line="$(echo "$generations" | head -n1)"
	fi

	local selected_path selected_num
	selected_path="$(echo "$selected_line" | cut -d: -f4)"
	selected_num="$(echo "$selected_line" | cut -d: -f1)"
	echo "booting NixOS generation ${selected_num}"
	INIT_PATH="${selected_path}"
}

print_selector() {
	local rootfs_partitions="$1"
	local i=1

	local rtc_time battery_soc
	rtc_time="$(read_rtc_time)"
	battery_soc="$(read_battery_soc)"

	echo "┌────────────────────────────────────────┐"
	echo "│           Shimboot OS Selector         │"
	printf "│  time: %-31s│\n" "$rtc_time"
	printf "│  battery: %-28s│\n" "$battery_soc"
	echo "└────────────────────────────────────────┘"

	if [ "${rootfs_partitions}" ]; then
		for rootfs_partition in $rootfs_partitions; do
			local part_path=$(echo $rootfs_partition | cut -d ":" -f 1)
			local part_name=$(echo $rootfs_partition | cut -d ":" -f 2)
			if [ "$part_name" = "vendor" ]; then
				continue
			fi
			echo "${i}) ${part_name} on ${part_path}"
			i=$((i + 1))
		done
	else
		echo "no bootable partitions found. see shimboot documentation to mark a partition as bootable."
	fi

	echo "q) reboot"
	echo "p) poweroff"
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
	elif [ "$selection" = "p" ]; then
		echo "powering off."
		poweroff -f
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

		if [ "$part_name" = "vendor" ]; then
			continue
		fi

		if [ "$selection" = "$i" ]; then
			echo "selected $part_path"
			boot_target "$part_path"
			return 1
		fi

		i=$((i + 1))
	done

	echo "invalid selection"
	sleep 1
	return 1
}

exec_init() {
	if [ "$rescue_mode" = "1" ]; then
		echo "entering rescue shell instead of starting init"
		echo "run 'exec ${INIT_PATH}' to continue booting"
		if [ -f "/bin/bash" ]; then
			exec /bin/bash <"$TTY1" >>"$TTY1" 2>&1
		else
			exec /bin/sh <"$TTY1" >>"$TTY1" 2>&1
		fi
	else
		exec "$INIT_PATH" <"$TTY1" >>"$TTY1" 2>&1
	fi
}

boot_target() {
	local target="$1"

	echo "mounting rootfs"
	mkdir /newroot

	if [ -x "$(command -v cryptsetup)" ] && cryptsetup luksDump "$target" >/dev/null 2>&1; then
		cryptsetup open $target rootfs
		if ! mount -t ext4 /dev/mapper/rootfs /newroot 2>/dev/null; then
			if ! mount /dev/mapper/rootfs /newroot; then
				echo "mount failed for LUKS rootfs: /dev/mapper/rootfs"
				echo "available filesystems:"
				cat /proc/filesystems || true
				echo "blkid /dev/mapper/rootfs:"
				blkid /dev/mapper/rootfs || true
				return 1
			fi
		fi
	else
		if ! mount -t ext4 $target /newroot 2>/dev/null; then
			if ! mount $target /newroot; then
				echo "mount failed for $target"
				echo "available filesystems:"
				cat /proc/filesystems || true
				echo "blkid $target:"
				blkid $target || true
				return 1
			fi
		fi
	fi

	# NixOS detection via bare 'system' profile symlink — always present on NixOS,
	# does not depend on numbered generation links existing.
	INIT_PATH="/sbin/init"
	if is_nixos_root "/newroot"; then
		echo "NixOS rootfs detected"
		select_nixos_generation "/newroot"
		local nixos_sel_ret=$?
		if [ "$nixos_sel_ret" -eq 2 ]; then
			umount /newroot 2>/dev/null || true
			rmdir /newroot 2>/dev/null || true
			return 1
		elif [ "$nixos_sel_ret" -ne 0 ]; then
			echo "NixOS: no valid generations found, falling back to /sbin/init"
		fi
	fi

	bind_vendor_into

	if [ -f "/bin/frecon-lite" ]; then
		rm -f /dev/console
		touch /dev/console
		mount -o bind "$TTY1" /dev/console
	fi
	move_mounts /newroot

	echo "switching root (init=${INIT_PATH})"
	mkdir -p /newroot/bootloader
	pivot_root /newroot /newroot/bootloader
	exec_init
}

main() {
	echo "starting the shimboot bootloader"

	enable_debug_console "$TTY2"

	local valid_partitions="$(find_rootfs_partitions)"

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
