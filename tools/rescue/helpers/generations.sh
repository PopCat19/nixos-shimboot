#!/usr/bin/env bash
# generations.sh
#
# Purpose: Manage NixOS system generations (list, rollback, delete, diff).
#
# This module:
# - Lists all available generations with metadata
# - Rolls back to specified generation
# - Deletes old generations with garbage collection
# - Compares differences between generations

source "${BASH_SOURCE[0]%/*}/common.sh"

list_generations() {
	log_section "NixOS Generations"

	if [[ ! -d "$PROFILE_DIR" ]]; then
		log_error "Profile directory not found: $PROFILE_DIR"
		return 1
	fi

	# Get all system-*-link symlinks
	local generations=()
	mapfile -t generations < <(find "$PROFILE_DIR" -maxdepth 1 -type l -name "system-*-link" | sort -V)

	if [[ ${#generations[@]} -eq 0 ]]; then
		log_warn "No generations found"
		return 1
	fi

	local current_gen
	current_gen="$(resolve_mounted_link "$PROFILE_DIR/system" 2>/dev/null || true)"

	# Use gum table for better formatting
	local table_data=()
	for gen in "${generations[@]}"; do
		local gen_num gen_path gen_date gen_size is_current

		gen_num="$(basename "$gen" | sed 's/system-\([0-9]*\)-link/\1/')"
		gen_path="$(resolve_mounted_link "$gen")"
		gen_date="$(stat -c %y "$gen" | cut -d' ' -f1,2 | cut -d'.' -f1)"
		gen_size="$(du -sh "$gen_path" 2>/dev/null | cut -f1 || echo "?")"

		if [[ "$gen_path" == "$current_gen" ]]; then
			is_current="✓ ACTIVE"
		else
			is_current=""
		fi

		table_data+=("$gen_num	$gen_date	$gen_size	$is_current")
	done

	printf "%-8s %-20s %-10s %-12s\n" "GEN #" "DATE" "SIZE" "STATUS"
	echo "──────────────────────────────────────────────────────────"
	for row in "${table_data[@]}"; do
		IFS=$'\t' read -r gen_num gen_date gen_size is_current <<<"$row"
		if [[ "$is_current" == "✓ ACTIVE" ]]; then
			gum style --foreground 46 "$(printf "%-8s %-20s %-10s %-12s" "$gen_num" "$gen_date" "$gen_size" "$is_current")"
		else
			printf "%-8s %-20s %-10s %-12s\n" "$gen_num" "$gen_date" "$gen_size" "$is_current"
		fi
	done

	return 0
}

get_generation_list() {
	# Returns generation numbers for gum selection
	if [[ ! -d "$PROFILE_DIR" ]]; then
		return 1
	fi

	local generations=()
	mapfile -t generations < <(find "$PROFILE_DIR" -maxdepth 1 -type l -name "system-*-link" | sort -V)

	for gen in "${generations[@]}"; do
		local gen_num gen_date
		gen_num="$(basename "$gen" | sed 's/system-\([0-9]*\)-link/\1/')"
		gen_date="$(stat -c %y "$gen" | cut -d' ' -f1,2 | cut -d'.' -f1)"
		echo "$gen_num ($gen_date)"
	done
}

view_generation_details() {
	log_section "Generation Details"

	list_generations || return 1

	local gen_options=()
	mapfile -t gen_options < <(get_generation_list)

	local gen_choice
	gen_choice=$(gum choose "${gen_options[@]}" "← Back" --header "Select generation to view details:" --height 15)

	[[ -z "$gen_choice" || "$gen_choice" == "← Back" ]] && return 0

	local gen_num="${gen_choice%% (*}"
	local target_gen="$PROFILE_DIR/system-${gen_num}-link"

	if [[ ! -L "$target_gen" ]]; then
		log_error "Generation $gen_num not found"
		return 1
	fi

	local gen_path
	gen_path="$(resolve_mounted_link "$target_gen")"

	local current_gen
	current_gen="$(resolve_mounted_link "$PROFILE_DIR/system" 2>/dev/null || true)"

	echo
	gum style --border normal --margin "1" --padding "1 2" --border-foreground 62 \
		"Generation $gen_num"

	echo
	gum style --foreground 141 "Details:"
	echo "  Path: $gen_path"
	echo "  Created: $(stat -c %y "$target_gen" | cut -d'.' -f1)"
	echo "  Size: $(du -sh "$gen_path" 2>/dev/null | cut -f1 || echo "?")"

	if [[ "$gen_path" == "$current_gen" ]]; then
		gum style --foreground 46 "  Status: ✓ ACTIVE (current system profile)"
	else
		gum style --foreground 214 "  Status: Inactive"
	fi

	# Try to extract nixpkgs version from the generation
	local nixpkgs_version=""
	if [[ -f "$gen_path/nixos-version" ]]; then
		nixpkgs_version="$(cat "$gen_path/nixos-version" 2>/dev/null || true)"
		echo "  NixOS Version: ${nixpkgs_version:-Unknown}"
	fi

	# Show kernel version if available
	local kernel_version=""
	if [[ -f "$gen_path/kernel" ]]; then
		kernel_version="$(file "$gen_path/kernel" 2>/dev/null | grep -oP 'version \K[0-9.]+' || true)"
		echo "  Kernel Version: ${kernel_version:-Unknown}"
	fi

	echo
	gum style --foreground 141 "Contents:"
	echo "  Packages: $(ls "$gen_path/sw/bin" 2>/dev/null | wc -l) binaries in /sw/bin"
	echo "  System units: $(ls "$gen_path/systemd" 2>/dev/null | wc -l) unit files"

	echo
	if gum confirm "View full generation contents?" --default=false; then
		echo
		log_info "Generation directory contents:"
		ls -la "$gen_path" | less
	fi

	return 0
}

rollback_generation() {
	log_section "Rollback Generation"

	list_generations || return 1

	local gen_options=()
	mapfile -t gen_options < <(get_generation_list)

	local gen_choice
	gen_choice=$(gum choose "${gen_options[@]}" "← Back" --header "Select generation to rollback to:" --height 15)

	[[ -z "$gen_choice" || "$gen_choice" == "← Back" ]] && {
		log_info "Rollback cancelled"
		return 0
	}

	local gen_num="${gen_choice%% (*}"
	local target_gen="$PROFILE_DIR/system-${gen_num}-link"

	if [[ ! -L "$target_gen" ]]; then
		log_error "Generation $gen_num not found"
		return 1
	fi

	local target_path
	target_path="$(resolve_mounted_link "$target_gen")"

	local current_gen
	current_gen="$(resolve_mounted_link "$PROFILE_DIR/system" 2>/dev/null || true)"

	# Check if already active
	if [[ "$target_path" == "$current_gen" ]]; then
		log_warn "Generation $gen_num is already the active system profile"
		return 0
	fi

	echo
	gum style --border normal --margin "1" --padding "1 2" --border-foreground 214 \
		"Rollback Preview"

	echo
	log_info "Target Generation: $gen_num"
	log_info "Path: $target_path"
	log_info "Created: $(stat -c %y "$target_gen" | cut -d'.' -f1)"
	log_info "Size: $(du -sh "$target_path" 2>/dev/null | cut -f1 || echo "?")"

	# Show nixpkgs version if available
	if [[ -f "$target_path/nixos-version" ]]; then
		log_info "NixOS Version: $(cat "$target_path/nixos-version" 2>/dev/null || echo 'Unknown')"
	fi

	echo
	if gum confirm "View generation contents before rollback?" --default=false; then
		echo
		log_info "Generation directory contents:"
		ls -la "$target_path" | less
	fi

	echo
	log_warn "⚠ This will switch the system profile to generation $gen_num"
	log_warn "⚠ You will need to reboot for changes to take effect"

	if ! gum confirm "Proceed with rollback?" --default=false; then
		log_info "Rollback cancelled"
		return 0
	fi

	# Create new system profile symlink
	log_info "Rolling back to generation $gen_num..."
	rm -f "$PROFILE_DIR/system"
	ln -s "$target_path" "$PROFILE_DIR/system"

	log_success "Rolled back to generation $gen_num"
	log_info "Reboot for changes to take effect"

	return 0
}

delete_generations() {
	log_section "Delete Old Generations"

	list_generations || return 1

	log_warn "⚠ WARNING: Deleting generations is irreversible!"
	log_warn "⚠ This will also run garbage collection to free disk space"
	echo

	local keep_count
	keep_count=$(gum input \
		--header "Keep last N generations:" \
		--placeholder "Enter a number (e.g., 5, 10)" \
		--prompt "> " \
		--value "5" \
		--char-limit=3)

	if ! [[ "$keep_count" =~ ^[0-9]+$ ]]; then
		log_error "Invalid number: $keep_count"
		return 1
	fi

	# Get all generations, sorted
	local generations=()
	mapfile -t generations < <(find "$PROFILE_DIR" -maxdepth 1 -type l -name "system-*-link" | sort -V)

	local total_count=${#generations[@]}
	local delete_count=$((total_count - keep_count))

	if [[ $delete_count -le 0 ]]; then
		log_info "No generations to delete (total: $total_count, keep: $keep_count)"
		return 0
	fi

	# Show which generations will be deleted
	echo
	gum style --foreground 214 "Generations to be deleted:"
	for ((i = 0; i < delete_count; i++)); do
		local gen="${generations[$i]}"
		local gen_num gen_date
		gen_num="$(basename "$gen" | sed 's/system-\([0-9]*\)-link/\1/')"
		gen_date="$(stat -c %y "$gen" | cut -d' ' -f1,2 | cut -d'.' -f1)"
		echo "  - Gen $gen_num ($gen_date)"
	done

	echo
	gum style --foreground 46 "Generations to keep:"
	for ((i = delete_count; i < total_count; i++)); do
		local gen="${generations[$i]}"
		local gen_num gen_date
		gen_num="$(basename "$gen" | sed 's/system-\([0-9]*\)-link/\1/')"
		gen_date="$(stat -c %y "$gen" | cut -d' ' -f1,2 | cut -d'.' -f1)"
		echo "  ✓ Gen $gen_num ($gen_date)"
	done

	echo
	log_warn "Will delete $delete_count generation(s), keeping newest $keep_count"

	if ! gum confirm "Proceed with deletion?" --default=false; then
		log_info "Deletion cancelled"
		return 0
	fi

	# Delete old generations
	for ((i = 0; i < delete_count; i++)); do
		local gen="${generations[$i]}"
		local gen_num
		gen_num="$(basename "$gen" | sed 's/system-\([0-9]*\)-link/\1/')"

		log_info "Deleting generation $gen_num..."
		rm -f "$gen"
	done

	# Garbage collect
	log_info "Running garbage collection..."
	local gc_output gc_exit
	gc_output=$(nix store gc --store "local?root=$MOUNTPOINT" 2>&1) || gc_exit=$?

	if [[ -z "${gc_exit:-}" ]]; then
		log_success "Garbage collection completed"
		log_success "Deleted $delete_count generation(s)"
	else
		log_warn "Garbage collection exited with code $gc_exit"
		echo "$gc_output" | gum pager --header "GC Output"
		log_warn "Deleted $delete_count generation(s), but garbage collection had issues"
	fi

	return 0
}

view_generation_diff() {
	log_section "Generation Diff"

	list_generations || return 1

	local gen_options=()
	mapfile -t gen_options < <(get_generation_list)

	local gen1_choice gen2_choice
	gen1_choice=$(gum choose "${gen_options[@]}" "← Back" --header "Select first generation:" --height 15)
	[[ -z "$gen1_choice" || "$gen1_choice" == "← Back" ]] && return 0

	gen2_choice=$(gum choose "${gen_options[@]}" "← Back" --header "Select second generation:" --height 15)
	[[ -z "$gen2_choice" || "$gen2_choice" == "← Back" ]] && return 0

	local gen1="${gen1_choice%% (*}"
	local gen2="${gen2_choice%% (*}"

	local gen1_path="$PROFILE_DIR/system-${gen1}-link"
	local gen2_path="$PROFILE_DIR/system-${gen2}-link"

	if [[ ! -L "$gen1_path" ]] || [[ ! -L "$gen2_path" ]]; then
		log_error "Invalid generation number(s)"
		return 1
	fi

	log_info "Comparing generation $gen1 → $gen2..."

	local store_path1 store_path2
	store_path1="$(resolve_store_path "$gen1_path")"
	store_path2="$(resolve_store_path "$gen2_path")"

	nix store diff-closures --store "local?root=$MOUNTPOINT" "$store_path1" "$store_path2" | less

	return 0
}
