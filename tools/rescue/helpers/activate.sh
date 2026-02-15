#!/usr/bin/env bash
# activate.sh
#
# Purpose: Inspect and manage stage-2 activation scripts.
#
# This module:
# - Lists activation script contents
# - Searches activation scripts with grep
# - Edits activation scripts for debugging

source "${BASH_SOURCE[0]%/*}/common.sh"
source "${BASH_SOURCE[0]%/*}/mount.sh"
source "${BASH_SOURCE[0]%/*}/generations.sh"

find_latest_activation_script() {
	if [[ "$MOUNTED" -eq 0 ]]; then
		mount_system "ro" || return 1
	fi

	# Find latest generation
	local generations=()
	mapfile -t generations < <(find "$PROFILE_DIR" -maxdepth 1 -type l -name "system-*-link" | sort -V)

	local latest_gen="${generations[-1]:-}"

	if [[ -z "$latest_gen" ]]; then
		log_error "No generations found"
		return 1
	fi

	local latest_target
	latest_target=$(readlink -f "$latest_gen")
	local activate_path="$MOUNTPOINT$latest_target/activate"

	if [[ ! -f "$activate_path" ]]; then
		log_error "Activation script not found"
		return 1
	fi

	echo "$activate_path"
}

view_activation_script() {
	local activate_path="$1"

	if [[ ! -f "$activate_path" ]]; then
		log_error "Activation script not found: $activate_path"
		return 1
	fi

	log_info "Activation script: $activate_path"
	head -n 40 "$activate_path" | less
}

search_activation_script() {
	local activate_path="$1"

	if [[ ! -f "$activate_path" ]]; then
		log_error "Activation script not found"
		return 1
	fi

	local pattern
	pattern=$(gum input --header "Enter grep pattern:" --value "")

	[[ -z "$pattern" ]] && return 0

	grep -n -H "$pattern" "$activate_path" || log_warn "No matches"
}

edit_activation_script() {
	local activate_path="$1"

	if [[ ! -f "$activate_path" ]]; then
		log_error "Activation script not found"
		return 1
	fi

	remount_system_rw

	"$EDITOR" "$activate_path"
	log_success "Edit complete"
}

activate_menu() {
	log_section "Stage-2 Activation Script (legacy)"

	local activate_path
	activate_path=$(find_latest_activation_script)

	if [[ -z "$activate_path" ]]; then
		return 1
	fi

	log_info "Activation script: $activate_path"

	local options=(
		"List first 40 lines"
		"Search (custom grep pattern)"
		"Edit activation script"
		"Back to main menu"
	)

	while true; do
		local choice
		choice=$(gum choose "${options[@]}" --header "Select action:" --height 8)

		[[ -z "$choice" ]] && return 0

		case "$choice" in
		"List first 40 lines")
			view_activation_script "$activate_path"
			;;
		"Search (custom grep pattern)")
			search_activation_script "$activate_path"
			;;
		"Edit activation script")
			edit_activation_script "$activate_path"
			;;
		"Back to main menu")
			return 0
			;;
		esac
	done
}
