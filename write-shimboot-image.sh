#!/usr/bin/env bash

# Write Shimboot Image Script
#
# Purpose: Safely write shimboot image to target disk with interactive device selection and validation
# Dependencies: sudo, dd, lsblk, findmnt, udisksctl, parted, cgpt, numfmt
# Related: assemble-final.sh, inspect-image.sh
#
# This script provides a safe, interactive interface for writing shimboot images to disks,
# with automatic system disk detection, UDisks integration, and comprehensive validation.
#
# Usage:
#   sudo ./write-shimboot-image.sh -o /dev/sdX

set -euo pipefail

# ---------- Defaults ----------
DEFAULT_IMAGE="/home/popcat19/nixos-shimboot/work/shimboot.img"
INPUT_IMAGE="${DEFAULT_IMAGE}"
OUTPUT_DEVICE=""
SKIP_CONFIRM="false"
COUNTDOWN=10
DRY_RUN="false"
LIST_ONLY="false"
LIST_ALL="false"
ALLOW_PARTITION="false"
AUTO_UNMOUNT="true"
ALLOW_LARGE="false"
# Ignore list entries
IGNORE_ENTRIES=()

# Derived/ephemeral
INTERACTIVE="false"
if [[ -t 0 && -t 1 ]]; then
	INTERACTIVE="true"
fi

# Will be set when OUTPUT_DEVICE is known

# System disk names to exclude from candidates (pkname list: "sda nvme0n1 ...")
SYSTEM_PKNAMES=""

# ---------- Color and Logging ----------
# Color setup
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
	RED=$'\e[31m'
	GREEN=$'\e[32m'
	YELLOW=$'\e[33m'
	BLUE=$'\e[34m'
	MAGENTA=$'\e[35m'
	CYAN=$'\e[36m'
	BOLD=$'\e[1m'
	DIM=$'\e[2m'
	RESET=$'\e[0m'
else
	RED=""
	GREEN=""
	YELLOW=""
	BLUE=""
	MAGENTA=""
	CYAN=""
	BOLD=""
	DIM=""
	RESET=""
fi

# Logging functions
info() { echo -e "${CYAN}$*${RESET}"; }
note() { echo -e "${BLUE}$*${RESET}"; }
action() { echo -e "${MAGENTA}$*${RESET}"; }
warn() { echo -e "${YELLOW}WARN:${RESET} $*" >&2; }
error() { echo -e "${RED}ERROR:${RESET} $*" >&2; }
success() { echo -e "${GREEN}$*${RESET}"; }
section() {
	local title="$1"
	echo
	echo -e "${BOLD}${title}${RESET}"
	echo -e "${DIM}$(printf '%*s' 80 '' | tr ' ' '-')${RESET}"
}

# ---------- Cleanup/exit handling ----------
SCRIPT_STATUS=0
on_exit() {
	SCRIPT_STATUS=$?
	udevadm settle >/dev/null 2>&1 || true

	if [[ "${SCRIPT_STATUS}" -ne 0 ]]; then
		echo
		error "Aborted with exit code ${SCRIPT_STATUS}."
	fi
	exit "${SCRIPT_STATUS}"
}
trap on_exit EXIT

# ---------- General helpers ----------
has_command() { command -v "$1" >/dev/null 2>&1; }

prompt_yes_no() {
	local prompt="$1"
	local default="${2:-y}" # y/n
	local ans
	if [[ "${INTERACTIVE}" != "true" ]]; then
		if [[ "${default}" == "y" ]]; then
			echo "yes"
		else
			echo "no"
		fi
		return 0
	fi
	while true; do
		if [[ "${default}" == "y" ]]; then
			read -r -p "$(echo -e "${BOLD}${prompt}${RESET} [${GREEN}Y${RESET}/n]: ")" ans || {
				echo "no"
				return 0
			}
			ans="${ans:-Y}"
		else
			read -r -p "$(echo -e "${BOLD}${prompt}${RESET} [y/${RED}N${RESET}]: ")" ans || {
				echo "no"
				return 0
			}
			ans="${ans:-N}"
		fi
		case "${ans}" in
		y | Y)
			echo "yes"
			return 0
			;;
		n | N)
			echo "no"
			return 0
			;;
		*) warn "Please answer y or n." ;;
		esac
	done
}

# ---------- Root escalation ----------
require_root() {
	if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
		warn "Re-executing with sudo..."
		exec sudo "$0" "$@"
	fi
}

# ---------- Help ----------
print_help() {
	cat <<'EOF'
Usage:
  write-shimboot-image.sh [options]

Options:
  -i, --input PATH         Input image path (default: /home/popcat19/nixos-shimboot/work/shimboot.img)
  -o, --output DEVICE      Output block device (e.g., /dev/sdX or /dev/mmcblkX)
  --yes                    Skip countdown confirmation (DANGEROUS; still prints warning)
  --countdown N            Confirmation countdown seconds (default: 10)
  --dry-run                Show what would happen without writing
  --list                   List candidate devices and exit
  --list-all               List all disks (including mounted ones) and exit
  --auto-unmount           Attempt to unmount target device automatically (default)
  --no-auto-unmount        Do not try to unmount; abort if mounted
  --force-part             Allow writing to a partition (TYPE=part). Use with extreme caution!
  --ignore LIST            Comma-separated device names or /dev paths to hide and block (e.g., "sda,/dev/sdc")
  --ignore-file PATH       File with one entry per line (device name or /dev path); lines starting with # are ignored
  --allow-large            Allow targets > 128GiB without extra confirmation (non-interactive)
  -h, --help               Show this help
EOF
}

# ---------- System disk detection ----------
# Get top-level physical disk name (pkname) for a device or mapper path
pk_of() {
	local src="$1"
	src="$(readlink -f "$src" 2>/dev/null || echo "$src")"
	local pk
	pk="$(lsblk -no PKNAME "$src" 2>/dev/null | head -n1 || true)"
	if [[ -n "$pk" ]]; then
		echo "$pk"
		return 0
	fi
	# Fallback: NAME itself (covers whole-disk paths)
	pk="$(lsblk -no NAME "$src" 2>/dev/null | head -n1 || true)"
	[[ -n "$pk" ]] && echo "$pk"
}

# Add pkname to SYSTEM_PKNAMES if not already present
add_system_pk() {
	local pk="$1"
	[[ -z "$pk" ]] && return 0
	if [[ " ${SYSTEM_PKNAMES} " != *" ${pk} "* ]]; then
		SYSTEM_PKNAMES="${SYSTEM_PKNAMES} ${pk}"
	fi
}

collect_system_pknames() {
	SYSTEM_PKNAMES=""
	local src pk

	# Root
	if src="$(findmnt -no SOURCE / 2>/dev/null)"; then
		pk="$(pk_of "$src")"
		add_system_pk "$pk"
	fi

	# Home
	if src="$(findmnt -no SOURCE /home 2>/dev/null || true)"; then
		[[ -n "$src" ]] && {
			pk="$(pk_of "$src")"
			add_system_pk "$pk"
		}
	fi

	# Boot and EFI
	if src="$(findmnt -no SOURCE /boot 2>/dev/null || true)"; then
		[[ -n "$src" ]] && {
			pk="$(pk_of "$src")"
			add_system_pk "$pk"
		}
	fi
	if src="$(findmnt -no SOURCE /boot/efi 2>/dev/null || true)"; then
		[[ -n "$src" ]] && {
			pk="$(pk_of "$src")"
			add_system_pk "$pk"
		}
	fi

	# Swap devices
	if [[ -r /proc/swaps ]]; then
		# Skip swap files, include block devices
		while read -r filename type _; do
			[[ "$filename" == Filename* ]] && continue
			if [[ "$type" == "partition" || "$filename" == /dev/* ]]; then
				pk="$(pk_of "$filename")"
				add_system_pk "$pk"
			fi
		done < <(awk '{print $1" "$2}' /proc/swaps)
	fi

	# Trim leading space
	SYSTEM_PKNAMES="${SYSTEM_PKNAMES#" "}"
}

is_system_pk() {
	local name="$1"
	[[ -n "$name" && " ${SYSTEM_PKNAMES} " == *" ${name} "* ]]
}

# ---------- Ignore list ----------
# Add ignore entries: supports device base names (e.g., sda, nvme0n1) and /dev paths (globs allowed)
add_ignore_entry() {
	local e="$1"
	[[ -z "${e:-}" ]] && return 0
	IGNORE_ENTRIES+=("$e")
}

# Load ignore entries from file (one per line; '#' comments and blanks ignored)
load_ignore_file() {
	local f="$1"
	if [[ -z "${f:-}" || ! -f "$f" ]]; then
		error "Ignore file not found: ${f}"
		exit 2
	fi
	while IFS= read -r line || [[ -n "$line" ]]; do
		# strip comments and trim whitespace
		line="$(printf '%s' "$line" | sed -e 's/#.*$//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
		[[ -z "$line" ]] && continue
		add_ignore_entry "$line"
	done <"$f"
}

# Check if a base device name is ignored (supports glob patterns)
is_ignored_name() {
	local name="$1"
	local e
	for e in "${IGNORE_ENTRIES[@]:-}"; do
		[[ -z "${e:-}" ]] && continue
		[[ "$e" == /* ]] && continue # path entry, skip here
		if [[ "$name" == "$e" ]]; then
			return 0
		fi
	done
	return 1
}

# Check if a device path is ignored (supports glob patterns)
is_ignored_path() {
	local path="$1"
	local e
	for e in "${IGNORE_ENTRIES[@]:-}"; do
		[[ -z "${e:-}" ]] && continue
		if [[ "$e" == /* ]]; then
			if [[ "$path" == "$e" ]]; then
				return 0
			fi
		fi
	done
	return 1
}

# ---------- UDisks detection/listing ----------
udisks_running() {
	pgrep -x udisksd >/dev/null 2>&1 || systemctl is-active --quiet udisks2.service 2>/dev/null || return 1
}

list_udisks_mounts() {
	# SOURCE TARGET OPTIONS (include either uhelper=udisks2 or mountpoints under /run/media or /media)
	findmnt -rn -o SOURCE,TARGET,OPTIONS |
		awk -F' ' '{src=$1; tgt=$2; opts=""; for(i=3;i<=NF;i++){opts=opts" "$i} gsub(/^ /,"",opts); print src "|" tgt "|" opts}' |
		grep -E '(\|/run/media/|\|/media/|uhelper=udisks2)' || true
}

print_udisks_section() {
	if ! udisks_running; then
		return 0
	fi
	local mounts
	mounts="$(list_udisks_mounts || true)"
	section "UDisks-managed mounts"
	if [[ -z "$mounts" ]]; then
		note "No UDisks (uhelper=udisks2) mounts detected."
		return 0
	fi

	printf "%-30s %-40s %-10s %s\n" "SOURCE" "TARGET" "DISK" "OPTS"
	echo "----------------------------------------------------------------------------------------------------"
	while IFS= read -r line; do
		[[ -z "$line" ]] && continue
		local src tgt opts pk
		src="$(awk -F'|' '{print $1}' <<<"$line")"
		tgt="$(awk -F'|' '{print $2}' <<<"$line")"
		opts="$(awk -F'|' '{print $3}' <<<"$line")"
		pk="$(pk_of "$src")"
		printf "${YELLOW}%-30s %-40s %-10s %s${RESET}\n" "$src" "$tgt" "${pk:-?}" "$opts"
	done <<<"$mounts"
}

# ---------- Disks/partitions display ----------
print_disks_overview() {
	section "Disks and partitions overview"
	lsblk -e7 -o NAME,PATH,SIZE,TYPE,TRAN,MOUNTPOINT,MODEL
}

print_device_tree() {
	local dev="$1"
	section "Target device tree for ${BOLD}${dev}${RESET}"
	if ! lsblk "$dev" -o NAME,PATH,SIZE,TYPE,TRAN,MOUNTPOINT,MODEL; then
		lsblk
	fi
}

# ---------- Disk information helpers ----------
# Get disk information as pipe-separated lines
get_disk_info() {
	lsblk -dn -o NAME,PATH,SIZE,MODEL,TRAN,RM,ROTA,TYPE |
		awk '{name=$1; path=$2; size=$3; model=""; tran=""; rm=""; rota=""; type="";
             for (i=4; i<=NF-4; i++) model = model $i " ";
             tran=$(NF-3); rm=$(NF-2); rota=$(NF-1); type=$(NF);
             gsub(/ *$/, "", model);
             print name "|" path "|" size "|" model "|" tran "|" rm "|" rota "|" type }'
}

# Parse a disk info line into variables
parse_disk_line() {
	local line="$1"
	name="$(awk -F'|' '{print $1}' <<<"$line")"
	path="$(awk -F'|' '{print $2}' <<<"$line")"
	size="$(awk -F'|' '{print $3}' <<<"$line")"
	model="$(awk -F'|' '{print $4}' <<<"$line")"
	tran="$(awk -F'|' '{print $5}' <<<"$line")"
	rm="$(awk -F'|' '{print $6}' <<<"$line")"
	rota="$(awk -F'|' '{print $7}' <<<"$line")"
	type="$(awk -F'|' '{print $8}' <<<"$line")"
}

# ---------- Candidate listing ----------
list_candidates() {
	echo -e "${BOLD}SAFE candidate devices (not mounted, not system disks):${RESET}"
	printf "%-12s %-10s %-8s %-6s %-4s %-5s %s\n" "DEVICE" "SIZE" "TRAN" "RM" "ROTA" "TYPE" "MODEL"
	echo "--------------------------------------------------------------------------------"
	while IFS= read -r line; do
		local name path size model tran rm rota type
		parse_disk_line "$line"

		[[ "$type" == "disk" ]] || continue
		if [[ "$name" =~ ^loop|^zram|^ram|^md|^dm- ]]; then
			continue
		fi
		# Exclude all known system pk names (root/home/boot/efi/swap)
		if is_system_pk "$name"; then
			continue
		fi

		# Exclude ignored devices (by name or path)
		if is_ignored_name "$name" || is_ignored_path "$path"; then
			continue
		fi

		# Must have no mounted descendants
		if lsblk -nr "$path" -o MOUNTPOINT | grep -qE '\S'; then
			continue
		fi

		printf "%-12s %-10s %-8s %-6s %-4s %-5s %s\n" "$path" "$size" "$tran" "$rm" "$rota" "$type" "$model"
	done < <(get_disk_info)
}

# All disks view, marking MNT and SYS
list_all_disks() {
	printf "%-12s %-10s %-8s %-6s %-4s %-5s %-3s %-3s %-3s %s\n" "DEVICE" "SIZE" "TRAN" "RM" "ROTA" "TYPE" "MNT" "SYS" "IGN" "MODEL"
	echo "--------------------------------------------------------------------------------------------------------"
	while IFS= read -r line; do
		local name path size model tran rm rota type mnt="no" sys="no" ign="no"
		parse_disk_line "$line"

		[[ "$type" == "disk" ]] || continue
		if [[ "$name" =~ ^loop|^zram|^ram|^md|^dm- ]]; then
			continue
		fi

		if lsblk -nr "$path" -o MOUNTPOINT | grep -qE '\S'; then
			mnt="yes"
		fi
		if is_system_pk "$name"; then
			sys="yes"
		fi
		if is_ignored_name "$name" || is_ignored_path "$path"; then
			ign="yes"
		fi

		if [[ "$sys" == "yes" ]]; then
			printf "${RED}%-12s %-10s %-8s %-6s %-4s %-5s %-3s %-3s %-3s %s${RESET}\n" "$path" "$size" "$tran" "$rm" "$rota" "$type" "$mnt" "$sys" "$ign" "$model"
		elif [[ "$mnt" == "yes" ]]; then
			printf "${YELLOW}%-12s %-10s %-8s %-6s %-4s %-5s %-3s %-3s %-3s %s${RESET}\n" "$path" "$size" "$tran" "$rm" "$rota" "$type" "$mnt" "$sys" "$ign" "$model"
		elif [[ "$ign" == "yes" ]]; then
			printf "${MAGENTA}%-12s %-10s %-8s %-6s %-4s %-5s %-3s %-3s %-3s %s${RESET}\n" "$path" "$size" "$tran" "$rm" "$rota" "$type" "$mnt" "$sys" "$ign" "$model"
		else
			printf "%-12s %-10s %-8s %-6s %-4s %-5s %-3s %-3s %-3s %s\n" "$path" "$size" "$tran" "$rm" "$rota" "$type" "$mnt" "$sys" "$ign" "$model"
		fi
	done < <(get_disk_info)
}

# ---------- Unmount helpers ----------
unmount_partition() {
	local part="$1"
	local mp
	mp="$(lsblk -no MOUNTPOINT "$part" 2>/dev/null | head -n1 || true)"
	if [[ -z "$mp" ]]; then
		return 0
	fi
	action "Attempting to unmount ${part} from ${mp}"
	if has_command udisksctl; then
		udisksctl unmount -b "$part" >/dev/null 2>&1 || true
	fi
	umount "$part" >/dev/null 2>&1 || umount "$mp" >/dev/null 2>&1 || true
	umount -l "$part" >/dev/null 2>&1 || umount -l "$mp" >/dev/null 2>&1 || true
}

udisks_unmount_device() {
	local dev="$1"
	# Gather all child paths (partitions) under the device
	local parts
	mapfile -t parts < <(lsblk -nr "$dev" -o PATH | tail -n +2 || true)
	[[ ${#parts[@]} -eq 0 ]] && return 0

	# Build a regex that matches any of the partition device paths
	local re=""
	for p in "${parts[@]}"; do
		# Escape slashes for grep-compatible regex
		local e="${p//\//\\/}"
		if [[ -z "$re" ]]; then re="^${e}\$"; else re="${re}|^${e}\$"; fi
	done

	# Find udisks-managed mounts whose SOURCE matches our partitions
	local m
	while IFS= read -r m; do
		[[ -z "$m" ]] && continue
		local src tgt
		src="$(awk -F'|' '{print $1}' <<<"$m")"
		tgt="$(awk -F'|' '{print $2}' <<<"$m")"
		# Only act on our target's partitions
		if [[ "$src" =~ $re ]]; then
			action "UDisks auto-unmount ${tgt} (${src})"
			if has_command udisksctl; then
				udisksctl unmount -b "$src" >/dev/null 2>&1 || true
			fi
			umount "$tgt" >/dev/null 2>&1 || true
			umount -l "$tgt" >/dev/null 2>&1 || true
		fi
	done < <(list_udisks_mounts || true)

	udevadm settle >/dev/null 2>&1 || true
	return 0
}

ensure_unmounted() {
	local dev="$1"
	if ! lsblk -nr "$dev" -o MOUNTPOINT | grep -qE '\S'; then
		return 0
	fi
	if [[ "$AUTO_UNMOUNT" != "true" ]]; then
		error "Device has mounted partitions and --no-auto-unmount is set."
		return 1
	fi
	warn "Device has mounted partitions; attempting to unmount..."
	local iter=0 changed=1
	while [[ $changed -eq 1 && $iter -lt 6 ]]; do
		changed=0
		while IFS= read -r p; do
			local mp
			mp="$(lsblk -no MOUNTPOINT "$p" 2>/dev/null | head -n1 || true)"
			if [[ -n "$mp" ]]; then
				changed=1
				unmount_partition "$p"
			fi
		done < <(lsblk -nr "$dev" -o PATH | tail -n +2 || true)
		udevadm settle >/dev/null 2>&1 || true
		sleep 0.3
		((iter++))
	done
	if lsblk -nr "$dev" -o MOUNTPOINT | grep -qE '\S'; then
		error "Could not unmount all mountpoints on ${dev}."
		lsblk "$dev"
		return 1
	fi
	return 0
}

# ---------- Validation ----------
validate_output_device() {
	local dev="$1"

	if [[ ! -b "$dev" ]]; then
		error "Output '$dev' is not a block device."
		return 1
	fi

	# Prevent writing to the same path as input image
	if [[ "$dev" == "$INPUT_IMAGE" ]]; then
		error "Cannot write to the same path as input image."
		return 1
	fi

	local type name pk
	type="$(lsblk -no TYPE "$dev" 2>/dev/null | head -n1)"
	name="$(lsblk -no NAME "$dev" 2>/dev/null | head -n1)"
	pk="$(lsblk -no PKNAME "$dev" 2>/dev/null | head -n1)"
	pk="${pk:-$name}"

	if [[ "$type" != "disk" && "$ALLOW_PARTITION" != "true" ]]; then
		error "'$dev' is TYPE='$type'. Refusing to write to non-disk by default."
		note "If you really intend to write to a partition, re-run with --force-part."
		return 1
	fi

	# Refuse writing to any detected system disk (root/home/boot/efi/swap)
	if is_system_pk "$pk"; then
		error "Refusing to write to a system disk ('$pk') [root/home/boot/efi/swap]."
		return 1
	fi

	# Refuse writing to ignored devices
	if is_ignored_name "$pk" || is_ignored_path "$dev"; then
		error "Refusing to write to ignored device ('$dev')."
		return 1
	fi

	# Note: Device may have mounted partitions; will unmount after final confirmation.
	if lsblk -nr "$dev" -o MOUNTPOINT | grep -qE '\S'; then
		warn "Device has mounted partitions; will unmount after confirmation."
	fi

	return 0
}

# ---------- Size helpers ----------
bytes_of_file() {
	local f="$1"
	stat -Lc %s "$f"
}
bytes_of_device() {
	local dev="$1"
	lsblk -bdno SIZE "$dev"
}

# ---------- Confirmation ----------
confirm_countdown() {
	local seconds="$1"
	echo
	echo -e "${BOLD}About to write the image to the target device.${RESET}"
	echo -e "${RED}${BOLD}THIS WILL DESTROY ALL DATA on the target device.${RESET}"
	echo
	if [[ "$SKIP_CONFIRM" == "true" ]]; then
		warn "[--yes] Skipping countdown. Press Ctrl-C NOW to abort."
		sleep 1
		return 0
	fi

	info "Proceeding in ${BOLD}${seconds}${RESET}${CYAN} seconds. Press Ctrl-C to abort.${RESET}"
	trap 'echo; error "Aborted."; exit 130' INT
	while [[ "$seconds" -gt 0 ]]; do
		printf "${DIM}  %2d...${RESET}\r" "$seconds"
		sleep 1
		seconds=$((seconds - 1))
	done
	trap - INT
	echo "               "
}

# ---------- Interactive selection ----------
prompt_for_device() {
	print_disks_overview

	# UDisks section (list only; unmount happens after confirmation)
	print_udisks_section
	echo

	info "Scanning for candidate target devices..."
	echo
	printf "%-12s %-10s %-8s %-6s %-4s %-5s %s\n" "DEVICE" "SIZE" "TRAN" "RM" "ROTA" "TYPE" "MODEL"
	echo "--------------------------------------------------------------------------------"
	list_candidates || true
	echo
	note "If your device doesn't appear above due to being mounted or filtered, you can:"
	echo "  - Unmount it manually (see UDisks section above), or"
	echo "  - Press Enter to view all disks (including mounted/system) and then type its path."
	echo
	read -r -p "$(echo -e "Enter the full device path to write to (or press Enter to show all): ")" OUTPUT_DEVICE
	OUTPUT_DEVICE="${OUTPUT_DEVICE//[[:space:]]/}"
	if [[ -z "$OUTPUT_DEVICE" ]]; then
		echo
		info "All disks (MNT=${YELLOW}yes${RESET}, SYS=${RED}yes${RESET}):"
		list_all_disks
		echo
		read -r -p "$(echo -e "Enter the full device path to write to (e.g., /dev/sdX): ")" OUTPUT_DEVICE
		OUTPUT_DEVICE="${OUTPUT_DEVICE//[[:space:]]/}"
	fi
	if [[ -z "$OUTPUT_DEVICE" ]]; then
		error "No device entered. Aborting."
		exit 4
	fi
}

run_writer() {
	local img="$1" dev="$2"
	action "Writing with dd..."
	dd if="${img}" of="${dev}" bs=4M status=progress conv=fsync
}

# ---------- Main logic helpers ----------
handle_list_modes() {
	if [[ "$LIST_ONLY" == "true" ]]; then
		print_disks_overview
		list_candidates
		exit 0
	fi

	if [[ "$LIST_ALL" == "true" ]]; then
		print_disks_overview
		list_all_disks
		exit 0
	fi
}

# ---------- Main ----------
parse_args() {
	while [[ $# -gt 0 ]]; do
		case "$1" in
		-i | --input)
			INPUT_IMAGE="${2:-}"
			shift 2
			;;
		-o | --output)
			OUTPUT_DEVICE="${2:-}"
			shift 2
			;;
		--yes)
			SKIP_CONFIRM="true"
			shift
			;;
		--countdown)
			COUNTDOWN="${2:-}"
			shift 2
			;;
		--dry-run)
			DRY_RUN="true"
			shift
			;;
		--list)
			LIST_ONLY="true"
			shift
			;;
		--list-all)
			LIST_ALL="true"
			shift
			;;
		--auto-unmount)
			AUTO_UNMOUNT="true"
			shift
			;;
		--no-auto-unmount)
			AUTO_UNMOUNT="false"
			shift
			;;
		--force-part)
			ALLOW_PARTITION="true"
			shift
			;;
		--ignore)
			IFS=',' read -ra ignore_items <<<"${2:-}"
			for item in "${ignore_items[@]}"; do add_ignore_entry "$item"; done
			shift 2
			;;
		--ignore-file)
			load_ignore_file "${2:-}"
			shift 2
			;;
		--allow-large)
			ALLOW_LARGE="true"
			shift
			;;
		-h | --help)
			print_help
			exit 0
			;;
		*)
			error "Unknown argument: $1"
			print_help
			exit 2
			;;
		esac
	done
}

main() {
	# Ensure we have root privileges early to avoid env preservation complexity
	require_root "$@"

	# Parse command-line arguments
	parse_args "$@"

	# Collect system disk names to avoid overwriting them
	collect_system_pknames

	# Handle list-only modes
	handle_list_modes

	if [[ -z "${INPUT_IMAGE}" ]]; then
		error "No input image specified."
		print_help
		exit 2
	fi

	if [[ ! -f "${INPUT_IMAGE}" ]]; then
		error "Input image not found: ${INPUT_IMAGE}"
		exit 5
	fi

	# Prompt for device if none given
	if [[ -z "${OUTPUT_DEVICE}" ]]; then
		prompt_for_device
	fi

	# Pre-validation view
	print_device_tree "${OUTPUT_DEVICE}"

	# Validate device (do not unmount yet; inform only)
	if ! validate_output_device "${OUTPUT_DEVICE}"; then
		exit 6
	fi

	# Gather display info
	local dev_size_bytes img_size_bytes dev_size_h img_size_h model tran type name
	img_size_bytes="$(bytes_of_file "${INPUT_IMAGE}")"
	dev_size_bytes="$(bytes_of_device "${OUTPUT_DEVICE}")"
	img_size_h="$(numfmt --to=iec --suffix=B --format='%.2f' "${img_size_bytes}" 2>/dev/null || echo "${img_size_bytes} bytes")"
	dev_size_h="$(numfmt --to=iec --suffix=B --format='%.2f' "${dev_size_bytes}" 2>/dev/null || echo "${dev_size_bytes} bytes")"
	model="$(lsblk -dno MODEL "${OUTPUT_DEVICE}" | sed 's/[[:space:]]\+$//')"
	tran="$(lsblk -dno TRAN "${OUTPUT_DEVICE}" | sed 's/[[:space:]]\+$//')"
	type="$(lsblk -dno TYPE "${OUTPUT_DEVICE}")"
	name="$(lsblk -dno NAME "${OUTPUT_DEVICE}")"

	section "Planned write summary"
	echo "Input image: ${BOLD}${INPUT_IMAGE}${RESET}"
	echo "Image size:  ${BOLD}${img_size_h}${RESET}"
	echo
	echo "Target device: ${BOLD}${OUTPUT_DEVICE}${RESET} (${name})"
	echo "  Type:       ${type}"
	echo "  Size:       ${dev_size_h}"
	echo "  Model:      ${model:-N/A}"
	echo "  Transport:  ${tran:-N/A}"
	echo

	# Extra confirmation for large targets (> 128 GiB)
	local threshold=$((128 * 1024 * 1024 * 1024))
	if [[ "${dev_size_bytes}" -gt "${threshold}" ]]; then
		warn "Target device capacity ${BOLD}${dev_size_h}${RESET} exceeds 128GiB."
		if [[ "${INTERACTIVE}" == "true" ]]; then
			local ans2
			ans2="$(prompt_yes_no "Are you absolutely sure you want to image a ${dev_size_h} device?" "n")"
			if [[ "$ans2" != "yes" ]]; then
				error "Aborting by user decision."
				exit 10
			fi
		else
			if [[ "${ALLOW_LARGE}" != "true" ]]; then
				error "Large target (${dev_size_h}) in non-interactive mode requires --allow-large."
				exit 10
			fi
		fi
	fi

	# Size sanity check
	if [[ "${img_size_bytes}" -gt "${dev_size_bytes}" ]]; then
		error "Image (${img_size_h}) is larger than target device (${dev_size_h}). Aborting."
		exit 7
	fi

	if [[ "${DRY_RUN}" == "true" ]]; then
		info "[DRY-RUN] Would write using dd"
		echo "[DRY-RUN] dd if='${INPUT_IMAGE}' of='${OUTPUT_DEVICE}' bs=4M status=progress conv=fsync"
		info "[DRY-RUN] No data has been written."
		exit 0
	fi

	confirm_countdown "${COUNTDOWN}"

	# After confirmation: unmount UDisks-managed mounts first, then ensure fully unmounted
	udisks_unmount_device "${OUTPUT_DEVICE}"
	if ! ensure_unmounted "${OUTPUT_DEVICE}"; then
		error "Device became mounted again (auto-mount likely). Aborting to be safe."
		exit 8
	fi

	# One more view before write starts
	print_device_tree "${OUTPUT_DEVICE}"

	# Write
	run_writer "${INPUT_IMAGE}" "${OUTPUT_DEVICE}"

	action "Syncing buffers..."
	sync

	success "Completed writing image to ${OUTPUT_DEVICE}."
	note "You may now remove the device safely after ensuring all activity LEDs are idle."
}

main "$@"
