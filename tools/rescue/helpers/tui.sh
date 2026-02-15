#!/usr/bin/env bash
# tui.sh
#
# Purpose: Main gum TUI menu loop with header display and routing.
#
# This module:
# - Displays system status header
# - Routes to sub-menus based on user selection
# - Provides main menu loop with gum choose

source "${BASH_SOURCE[0]%/*}/common.sh"
source "${BASH_SOURCE[0]%/*}/detect.sh"
source "${BASH_SOURCE[0]%/*}/mount.sh"
source "${BASH_SOURCE[0]%/*}/generations.sh"
source "${BASH_SOURCE[0]%/*}/filesystem.sh"
source "${BASH_SOURCE[0]%/*}/home.sh"
source "${BASH_SOURCE[0]%/*}/bootstrap.sh"
source "${BASH_SOURCE[0]%/*}/activate.sh"

show_header() {
	clear
	gum style --border normal --margin "1" --padding "1 2" --border-foreground 62 \
		"NixOS Shimboot Rescue Helper"
	echo
	gum style --foreground 240 \
		"System: $TARGET_PARTITION"
	gum style --foreground 240 \
		"Mount: $MOUNTPOINT ($(get_mount_mode))"
	echo
}

show_generation_menu() {
	if [[ "$MOUNTED" -eq 0 ]]; then
		mount_system "ro" || return 1
	fi

	local options=(
		"List generations"
		"Rollback generation"
		"Delete old generations"
		"View generation diff"
		"Back to main menu"
	)

	while true; do
		show_header
		log_section "Generation Management"

		local choice
		choice=$(gum choose "${options[@]}" --header "Select generation operation:" --height 10)

		[[ -z "$choice" ]] && return 0

		case "$choice" in
		"List generations")
			list_generations
			;;
		"Rollback generation")
			remount_system_rw
			rollback_generation
			;;
		"Delete old generations")
			remount_system_rw
			delete_generations
			;;
		"View generation diff")
			view_generation_diff
			;;
		"Back to main menu")
			return 0
			;;
		esac

		pause
	done
}

main_menu() {
	local categories=(
		"Generation Management"
		"Filesystem Operations"
		"Bootstrap Tools"
		"Home Directory Management"
		"Stage-2 Activation Script (legacy)"
		"Exit"
	)

	while true; do
		show_header

		local choice
		choice=$(gum choose "${categories[@]}" --header "Select operation category:" --height 10)

		[[ -z "$choice" ]] && {
			log_info "Goodbye!"
			exit 0
		}

		case "$choice" in
		"Generation Management")
			show_generation_menu
			;;
		"Filesystem Operations")
			filesystem_menu
			;;
		"Bootstrap Tools")
			bootstrap_menu
			;;
		"Home Directory Management")
			home_menu
			;;
		"Stage-2 Activation Script (legacy)")
			activate_menu
			;;
		"Exit")
			log_info "Goodbye!"
			exit 0
			;;
		esac
	done
}
