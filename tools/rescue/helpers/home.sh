#!/usr/bin/env bash
# home.sh
#
# Purpose: Export and import home directories with zstd compression.
#
# This module:
# - Exports user home directories to compressed archives
# - Imports home directories from backup archives
# - Lists home contents and backup archives
# - Uses pv for progress on large archives

source "${BASH_SOURCE[0]%/*}/common.sh"
source "${BASH_SOURCE[0]%/*}/mount.sh"

get_home_users() {
	if [[ -d "$MOUNTPOINT/home" ]]; then
		ls -1 "$MOUNTPOINT/home" 2>/dev/null
	fi
}

get_backup_archives() {
	mkdir -p "$HOME_BACKUP_DIR"
	find "$HOME_BACKUP_DIR" -maxdepth 1 -name "*.tar.zst" -type f -printf '%f\n' 2>/dev/null
}

get_backup_archives_array() {
	local archives=()
	mapfile -t archives < <(get_backup_archives)
	printf '%s\n' "${archives[@]}"
}

export_home() {
	log_section "Export Home Directory"

	local users
	users=$(get_home_users)

	if [[ -z "$users" ]]; then
		log_warn "No users found in /home"
		return 1
	fi

	local username
	local user_list=()
	mapfile -t user_list <<< "$users"
	username=$(gum choose "${user_list[@]}" --header "Select user to export:" --height 10)

	[[ -z "$username" ]] && {
		log_info "Export cancelled"
		return 0
	}

	if [[ ! -d "$MOUNTPOINT/home/$username" ]]; then
		log_error "User home not found: $username"
		return 1
	fi

	local timestamp archive_name archive_path
	timestamp="$(date +%Y%m%d_%H%M%S)"
	archive_name="${username}_home_${timestamp}.tar.zst"
	archive_path="$HOME_BACKUP_DIR/$archive_name"

	log_info "Exporting $username's home to $archive_path..."

	# Create metadata file
	local meta_file="/tmp/home_backup_meta_${timestamp}.txt"
	cat >"$meta_file" <<EOF
User: $username
Exported: $(date)
Source: $MOUNTPOINT/home/$username
Partition: $TARGET_PARTITION
EOF

	mkdir -p "$HOME_BACKUP_DIR"

	# Create archive with progress using pv
	local home_size
	home_size="$(du -sb "$MOUNTPOINT/home/$username" | cut -f1)"

	# Copy metadata into home dir temporarily so tar picks it up cleanly
	cp "$meta_file" "$MOUNTPOINT/home/$username/.backup_meta.txt"

	tar -C "$MOUNTPOINT/home" -cf - "$username" |
		pv -s "$home_size" |
		zstd -T0 -19 >"$archive_path"

	rm -f "$MOUNTPOINT/home/$username/.backup_meta.txt"
	rm -f "$meta_file"

	log_success "Exported to: $archive_path"
	log_info "Archive size: $(du -h "$archive_path" | cut -f1)"
}

import_home() {
	log_section "Import Home Directory"

	local archives=()
	mapfile -t archives < <(get_backup_archives)

	if [[ ${#archives[@]} -eq 0 ]]; then
		log_warn "No archives found in $HOME_BACKUP_DIR"

		if gum confirm "Import from a different directory?" --default=false; then
			local import_dir
			import_dir=$(gum input --header "Enter source directory path:" --value "$HOME_BACKUP_DIR")
			[[ -z "$import_dir" ]] && return 1

			if [[ -d "$import_dir" ]]; then
				HOME_BACKUP_DIR="$import_dir"
				mapfile -t archives < <(get_backup_archives)
				log_info "Import directory switched to: $HOME_BACKUP_DIR"
			else
				log_error "Directory not found: $import_dir"
				return 1
			fi
		else
			return 1
		fi
	fi

	log_info "Available archives in $HOME_BACKUP_DIR:"
	ls -lh "$HOME_BACKUP_DIR"/*.tar.zst 2>/dev/null || true
	echo

	local archive_file
	archive_file=$(gum choose "${archives[@]}" --header "Select archive to import:" --height 10)

	[[ -z "$archive_file" ]] && {
		log_info "Import cancelled"
		return 0
	}

	local archive_path="$HOME_BACKUP_DIR/$archive_file"
	if [[ ! -f "$archive_path" ]]; then
		log_error "Archive not found: $archive_path"
		return 1
	fi

	log_warn "This will overwrite existing home directory contents!"

	if ! gum confirm "Proceed with import?" --default=false; then
		log_info "Import cancelled"
		return 0
	fi

	remount_system_rw

	log_info "Importing from $archive_path..."

	pv "$archive_path" | zstd -d | tar -C "$MOUNTPOINT/home" -xf -

	log_success "Import complete"
}

list_home_contents() {
	log_section "Home Contents"

	local users
	users=$(get_home_users)

	if [[ -z "$users" ]]; then
		log_warn "No users found in /home"
		return 1
	fi

	log_info "Users in /home:"
	ls -lh "$MOUNTPOINT/home"
	echo

	local username
	local user_list=()
	mapfile -t user_list <<< "$users"
	username=$(gum choose "${user_list[@]}" "Skip" --header "Select user to inspect:" --height 10)

	[[ -z "$username" || "$username" == "Skip" ]] && return 0

	if [[ -d "$MOUNTPOINT/home/$username" ]]; then
		log_info "Contents of /home/$username:"
		du -h --max-depth=1 "$MOUNTPOINT/home/$username" 2>/dev/null | sort -hr | head -n 20
	fi
}

view_backup_archives() {
	log_section "Backup Archives"

	log_info "Backup archives in $HOME_BACKUP_DIR:"
	mkdir -p "$HOME_BACKUP_DIR"
	ls -lh "$HOME_BACKUP_DIR"/*.tar.zst 2>/dev/null || log_warn "No backups found"
}

change_backup_dir() {
	log_info "Current backup directory: $HOME_BACKUP_DIR"

	if gum confirm "Change backup directory?" --default=false; then
		local new_dir
		new_dir=$(gum input --header "Enter new backup directory path:" --value "$HOME_BACKUP_DIR")

		if [[ -n "$new_dir" ]]; then
			HOME_BACKUP_DIR="$new_dir"
			mkdir -p "$HOME_BACKUP_DIR"
			log_success "Backup directory changed to: $HOME_BACKUP_DIR"
		fi
	fi
}

home_menu() {
	if [[ "$MOUNTED" -eq 0 ]]; then
		mount_system "ro" || return 1
	fi

	set_breadcrumb "Main ▸ Home"
	log_info "Backup directory: $HOME_BACKUP_DIR"

	local options=(
		"Export home to zstd archive"
		"Import home from zstd archive"
		"List home contents"
		"View backup archives"
		"Change backup directory"
		"← Back to main menu"
	)

	while true; do
		show_header
		show_menu_header "Home Directory Management"

		local choice
		choice=$(gum choose "${options[@]}" --header "Select operation:" --height 10)

		[[ -z "$choice" ]] && return 0

		case "$choice" in
		"Export home to zstd archive")
			export_home
			;;
		"Import home from zstd archive")
			import_home
			;;
		"List home contents")
			list_home_contents
			;;
		"View backup archives")
			view_backup_archives
			;;
		"Change backup directory")
			change_backup_dir
			;;
		"← Back to main menu")
			return 0
			;;
		esac

		pause
	done
}
