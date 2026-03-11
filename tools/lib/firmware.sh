# firmware.sh
#
# Purpose: Provide firmware management functions for ChromeOS-derived images
#
# This module:
# - Prunes unused firmware files to reduce image size
# - Creates backup manifest before pruning

# shellcheck shell=bash

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
	find "$fw_dir" -type f >"$fw_dir/../firmware-manifest.txt" 2>/dev/null || true

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
	find "${find_args[@]}" 2>/dev/null || true

	# Remove empty directories
	find "$fw_dir" -type d -empty -delete 2>/dev/null || true

	# Report size after pruning
	local remaining_size
	remaining_size=$(du -sh "$fw_dir" 2>/dev/null | cut -f1)
	log_info "Firmware pruned to $remaining_size"
}
