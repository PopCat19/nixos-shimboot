#!/usr/bin/env bash

# prune-firmware.sh
#
# Purpose: Prune unused firmware files to reduce image size
#
# This module:
# - Removes firmware not essential for Chromebook boot/wifi/graphics
# - Keeps common families: intel, iwlwifi, rtw88, rtw89, brcm, ath10k, mediatek
# - Creates backup manifest before pruning

set -Eeuo pipefail

ANSI_CLEAR='\033[0m'
ANSI_BOLD='\033[1m'
ANSI_GREEN='\033[1;32m'
ANSI_BLUE='\033[1;34m'
ANSI_YELLOW='\033[1;33m'
ANSI_RED='\033[1;31m'

log_step() {
	printf "${ANSI_BOLD}${ANSI_BLUE}[%s] %s${ANSI_CLEAR}\n" "$1" "$2"
}
log_info() {
	printf "${ANSI_GREEN}  %s${ANSI_CLEAR}\n" "$1"
}
log_warn() {
	printf "${ANSI_YELLOW}  %s${ANSI_CLEAR}\n" "$1"
}
log_error() {
	printf "${ANSI_RED}  %s${ANSI_CLEAR}\n" "$1"
}

# Prune unused firmware files to reduce size
prune_unused_firmware() {
	local fw_dir="$1"

	# Safety check: verify we're in the right directory
	if [[ ! "$fw_dir" =~ /harvested/lib/firmware$ ]] &&
		[[ ! "$fw_dir" =~ /work/harvested/lib/firmware$ ]]; then
		log_error "Refusing to prune firmware: unsafe path $fw_dir"
		return 1
	fi

	# Backup firmware list before pruning
	log_info "Creating firmware backup manifest..."
	find "$fw_dir" -type f >"$fw_dir/../firmware-manifest.txt"

	log_step "Prune" "Conservatively pruning firmware..."

	# Keep common Chromebook firmware families (board-agnostic)
	local keep_families=(
		"intel"         # Intel WiFi/BT/GPU (most Chromebooks)
		"iwlwifi"       # Intel WiFi (standalone files)
		"rtw88"         # Realtek WiFi (newer)
		"rtw89"         # Realtek WiFi (newest)
		"brcm"          # Broadcom WiFi/BT
		"ath10k"        # Atheros WiFi
		"mediatek"      # MediaTek (new Chromebooks)
		"regulatory.db" # Required for WiFi
		"*.ucode"       # CPU microcode
	)

	log_info "Keeping essential Chromebook firmware families..."

	# Build find exclusion arguments safely using array (avoids eval injection)
	local find_args=("$fw_dir" -type f)
	for family in "${keep_families[@]}"; do
		find_args+=(! -path "*/$family/*" ! -name "$family*")
	done
	find_args+=(-delete)

	log_info "Removing unused firmware files..."
	find "${find_args[@]}"

	# Remove empty directories
	find "$fw_dir" -type d -empty -delete 2>/dev/null || true

	# Report size after pruning
	local remaining_size
	remaining_size=$(du -sh "$fw_dir" | cut -f1)
	log_info "Firmware pruned to $remaining_size"
}

# Run if executed directly (not sourced)
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
	if [ $# -lt 1 ]; then
		echo "Usage: $0 <firmware-directory>" >&2
		echo "Example: $0 ./harvested/lib/firmware" >&2
		exit 1
	fi
	prune_unused_firmware "$1"
fi
