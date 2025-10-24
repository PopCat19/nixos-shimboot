#!/usr/bin/env bash

# Collect Minimal Logs Script
#
# Purpose: Collect diagnostics from NixOS minimal rootfs for debugging LightDM/Xorg/PAM/journal issues
# Dependencies: sudo, lsblk, mount, umount, journalctl, grep, tail
# Related: test-board-builds.sh, harvest-drivers.sh
#
# This script enumerates block devices, mounts partitions read-only, and collects
# logs from LightDM, Xorg, PAM, and systemd journal for troubleshooting.
#
# Usage:
#   sudo ./tools/collect-minimal-logs.sh /dev/sdc4

set -euo pipefail

MNT_ARG="${1:-}"

SECTION() {
	echo
	echo "========== $* =========="
}

info() { printf "[INFO] %s\n" "$*" >&2; }
warn() { printf "[WARN] %s\n" "$*" >&2; }
err() { printf "[ERR ] %s\n" "$*" >&2; }

ensure_mountpoint() {
	sudo mkdir -p /mnt/inspect_rootfs
}

detect_from_lsblk() {
	info "Enumerating block devices (sudo lsblk)..."
	# NAME,SIZE,FSTYPE,MOUNTPOINT,TYPE,RM,HOTPLUG,MODEL
	sudo lsblk -p -o NAME,SIZE,FSTYPE,MOUNTPOINT,TYPE,RM,HOTPLUG,MODEL >&2
	echo >&2
	echo "Select a partition to inspect (e.g., /dev/sdc4)." >&2
	read -rp "Device path [/dev/sdc4]: " DEV
	DEV="${DEV:-/dev/sdc4}"
	if [[ ! -e "$DEV" ]]; then
		err "Device does not exist: $DEV"
		exit 2
	fi
	echo "$DEV"
}

mount_ro_if_needed() {
	local WHAT="$1"

	# If WHAT looks like a device, mount it read-only
	if [[ -b "$WHAT" ]]; then
		ensure_mountpoint

		# Unmount any existing mount points of THIS device (e.g., udisks mounts)
		# lsblk can print multiple lines; unmount each non-empty mountpoint.
		local mps
		mps="$(lsblk -no MOUNTPOINT "$WHAT" | sed -e '/^$/d' || true)"
		if [[ -n "$mps" ]]; then
			while IFS= read -r mp; do
				[[ -z "$mp" ]] && continue
				warn "Device $WHAT currently mounted at $mp; unmounting..."
				sudo umount "$mp" || true
			done <<<"$mps"
		fi

		# If our inspect mountpoint is in use, unmount it
		if mountpoint -q /mnt/inspect_rootfs; then
			warn "/mnt/inspect_rootfs already mounted; unmounting first..."
			sudo umount /mnt/inspect_rootfs || true
		fi

		info "Mounting $WHAT read-only at /mnt/inspect_rootfs"
		if ! sudo mount -o ro "$WHAT" /mnt/inspect_rootfs 2>/dev/null; then
			# Retry once after a short delay in case an automounter races
			sleep 0.5
			sudo umount /mnt/inspect_rootfs >/dev/null 2>&1 || true
			# Unmount again any mounts that may have re-appeared
			mps="$(lsblk -no MOUNTPOINT "$WHAT" | sed -e '/^$/d' || true)"
			if [[ -n "$mps" ]]; then
				while IFS= read -r mp; do
					[[ -z "$mp" ]] && continue
					warn "Retry: unmounting $mp..."
					sudo umount "$mp" || true
				done <<<"$mps"
			fi
			info "Retry mounting $WHAT read-only at /mnt/inspect_rootfs"
			sudo mount -o ro "$WHAT" /mnt/inspect_rootfs
		fi

		# Only echo the path on stdout so callers can capture it cleanly
		echo "/mnt/inspect_rootfs"
		return 0
	fi

	# Otherwise treat WHAT as a directory
	if [[ -d "$WHAT" ]]; then
		echo "$WHAT"
		return 0
	fi

	err "Not a block device or directory: $WHAT"
	exit 3
}

# Ensure cleanup: always unmount /mnt/inspect_rootfs and any mounts of /dev/sdc4 before exiting
cleanup() {
	set +e
	# Unmount our inspect mountpoint if mounted
	if mountpoint -q /mnt/inspect_rootfs; then
		sudo umount /mnt/inspect_rootfs || true
	fi

	# Ensure /dev/sdc4 is unmounted everywhere
	if [[ -b /dev/sdc4 ]]; then
		local mps
		mps="$(lsblk -no MOUNTPOINT /dev/sdc4 | sed -e '/^$/d' || true)"
		if [[ -n "$mps" ]]; then
			while IFS= read -r mp; do
				[[ -z "$mp" ]] && continue
				sudo umount "$mp" || true
			done <<<"$mps"
		fi
	fi
}

trap 'cleanup' EXIT INT TERM
print_basic() {
	local MNT="$1"
	info "Using mount: $MNT"

	SECTION "Listing $MNT/var/log"
	sudo ls -la "$MNT/var/log" || true
}

print_lightdm() {
	local MNT="$1"
	SECTION "LightDM logs"
	if [[ -d "$MNT/var/log/lightdm" ]]; then
		sudo ls -l "$MNT/var/log/lightdm" || true
		echo
		shopt -s nullglob
		local files=("$MNT"/var/log/lightdm/*)
		if ((${#files[@]} == 0)); then
			echo "(no files under $MNT/var/log/lightdm)"
		else
			for f in "${files[@]}"; do
				[[ -f "$f" ]] || continue
				echo "--- $f ---"
				sudo tail -n 300 "$f" || true
				echo
			done
		fi
	else
		echo "(no $MNT/var/log/lightdm)"
	fi
}

print_xorg() {
	local MNT="$1"
	SECTION "Xorg.0.log (errors/warnings)"
	if [[ -f "$MNT/var/log/Xorg.0.log" ]]; then
		echo "--- tail $MNT/var/log/Xorg.0.log ---"
		sudo tail -n 200 "$MNT/var/log/Xorg.0.log" || true
		echo
		echo "--- grep EE/WW ---"
		sudo grep -nE "^\(EE\)|^\(WW\)|fatal|error" -i "$MNT/var/log/Xorg.0.log" || true
	else
		echo "(no $MNT/var/log/Xorg.0.log)"
	fi
}

print_journal() {
	local MNT="$1"
	SECTION "Journal (lightdm/display-manager/seatd/logind) recent"
	if [[ -d "$MNT/var/log/journal" ]]; then
		if sudo journalctl --no-pager --directory="$MNT/var/log/journal" -n 1 >/dev/null 2>&1; then
			sudo journalctl --directory="$MNT/var/log/journal" \
				-u lightdm -u display-manager -u seatd -u systemd-logind \
				--no-pager -n 300 || true
		else
			echo "(journal present but not readable; attempting sudo with SYSTEMD_LOG_LEVEL=warning)"
			sudo SYSTEMD_LOG_LEVEL=warning journalctl --directory="$MNT/var/log/journal" \
				-u lightdm -u display-manager -u seatd -u systemd-logind \
				--no-pager -n 300 || true
		fi
	else
		echo "(no $MNT/var/log/journal)"
	fi
}

print_pam_and_users() {
	local MNT="$1"
	SECTION "PAM logs (auth.log if present)"
	if [[ -f "$MNT/var/log/auth.log" ]]; then
		sudo grep -iE "lightdm|pam|auth" "$MNT/var/log/auth.log" | tail -n 200 || true
	else
		echo "(no $MNT/var/log/auth.log)"
	fi

	SECTION "Users present (passwd)"
	sudo grep -E "^(root|nixos-shimboot):" "$MNT/etc/passwd" || true

	SECTION "Shadow presence (redacted)"
	if [[ -f "$MNT/etc/shadow" ]]; then
		sudo grep -E "^(root|nixos-shimboot):" "$MNT/etc/shadow" | sed 's/:[^:]*:/:(redacted):/' || true
	else
		echo "(no $MNT/etc/shadow)"
	fi

	SECTION "LightDM PAM configs"
	shopt -s nullglob
	local pam_files=("$MNT"/etc/pam.d/lightdm*)
	if ((${#pam_files[@]} == 0)); then
		echo "(no $MNT/etc/pam.d/lightdm*)"
	else
		for p in "${pam_files[@]}"; do
			[[ -f "$p" ]] || continue
			echo "--- $p ---"
			sudo sed -n '1,200p' "$p"
			echo
		done
	fi

	SECTION "nsswitch.conf"
	if [[ -f "$MNT/etc/nsswitch.conf" ]]; then
		sudo sed -n '1,200p' "$MNT/etc/nsswitch.conf"
	else
		echo "(no $MNT/etc/nsswitch.conf)"
	fi

	SECTION "login.defs"
	if [[ -f "$MNT/etc/login.defs" ]]; then
		sudo sed -n '1,200p' "$MNT/etc/login.defs"
	else
		echo "(no $MNT/etc/login.defs)"
	fi

	SECTION "seatd/logind configs"
	if [[ -d "$MNT/etc/seatd" ]]; then
		echo "== $MNT/etc/seatd =="
		sudo ls -la "$MNT/etc/seatd" || true
	else
		echo "(no $MNT/etc/seatd)"
	fi

	if [[ -d "$MNT/etc/systemd" ]]; then
		echo "== $MNT/etc/systemd (grep lightdm/logind) =="
		sudo grep -RinE 'lightdm|logind' "$MNT/etc/systemd" || true
	else
		echo "(no $MNT/etc/systemd)"
	fi
}

main() {
	local TARGET="$MNT_ARG"
	if [[ -z "$TARGET" ]]; then
		TARGET="$(detect_from_lsblk)"
	fi

	local MNT
	MNT="$(mount_ro_if_needed "$TARGET")"

	print_basic "$MNT"
	print_lightdm "$MNT"
	print_xorg "$MNT"
	print_journal "$MNT"
	print_pam_and_users "$MNT"

	echo
	info "Diagnostics complete."
}

main "$@"
