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
	local mode
	mode="$(get_mount_mode)"
	local mode_color="214"
	case "$mode" in
		ro) mode_color="46" ;;
		rw) mode_color="214" ;;
		unmounted) mode_color="240" ;;
	esac

	gum style --border double --margin "1" --padding "1 2" --border-foreground 62 \
		"NixOS Shimboot Rescue Helper" \
		"" \
		"Partition: $TARGET_PARTITION" \
		"Mount: $MOUNTPOINT ($(gum style --foreground "$mode_color" "$mode"))" \
		"Navigation: $BREADCRUMB"
	echo
}

show_menu_header() {
	local menu_title="$1"
	gum style --foreground 141 --bold "▸ $menu_title" --margin "0 0 1 0"
}

show_generation_menu() {
	if [[ "$MOUNTED" -eq 0 ]]; then
		mount_system "ro" || return 1
	fi

	set_breadcrumb "Main ▸ Generations"

	local options=(
		"List generations"
		"View generation details"
		"Rollback generation"
		"Delete old generations"
		"View generation diff"
		"← Back to main menu"
	)

	while true; do
		show_header
		show_menu_header "Generation Management"

		local choice
		choice=$(gum choose "${options[@]}" --header "Select operation:" --height 10)

		[[ -z "$choice" ]] && return 0

		case "$choice" in
		"List generations")
			list_generations
			;;
		"View generation details")
			view_generation_details
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
		"← Back to main menu")
			return 0
			;;
		esac

		pause
	done
}

main_menu() {
	set_breadcrumb "Main"

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
		show_menu_header "Main Menu"

		local choice
		choice=$(gum choose "${categories[@]}" --header "Select category:" --height 10)

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
