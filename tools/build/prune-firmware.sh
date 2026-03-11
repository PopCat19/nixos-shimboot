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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/logging.sh"
source "${SCRIPT_DIR}/lib/firmware.sh"

usage() {
	echo "Usage: $0 <firmware-directory>"
	echo ""
	echo "Prune unused firmware files to reduce image size."
	echo ""
	echo "Arguments:"
	echo "  firmware-directory    Path to firmware directory to prune"
	echo ""
	echo "Example:"
	echo "  $0 ./harvested/lib/firmware"
	exit 0
}

# Run if executed directly (not sourced)
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
	while [[ $# -gt 0 ]]; do
		case "$1" in
		-h | --help)
			usage
			;;
		-*)
			echo "Unknown option: $1" >&2
			usage
			exit 1
			;;
		*)
			break
			;;
		esac
		shift
	done

	if [ $# -lt 1 ]; then
		usage
	fi
	prune_unused_firmware "$1"
fi
