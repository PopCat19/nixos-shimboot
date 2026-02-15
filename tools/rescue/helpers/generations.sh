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
	current_gen="$(readlink -f "$PROFILE_DIR/system" 2>/dev/null || true)"

	printf "%-6s %-20s %-12s %-12s %s\n" "GEN" "DATE" "SIZE" "CURRENT" "PATH"
	echo "─────────────────────────────────────────────────────────────────────────────"

	for gen in "${generations[@]}"; do
		local gen_num gen_path gen_date gen_size is_current

		gen_num="$(basename "$gen" | sed 's/system-\([0-9]*\)-link/\1/')"
		gen_path="$(readlink -f "$gen")"
		gen_date="$(stat -c %y "$gen" | cut -d' ' -f1,2 | cut -d'.' -f1)"
		gen_size="$(du -sh "$gen_path" 2>/dev/null | cut -f1 || echo "?")"

		if [[ "$gen_path" == "$current_gen" ]]; then
			is_current="✓ (active)"
		else
			is_current=""
		fi

		printf "%-6s %-20s %-12s %-12s %s\n" "$gen_num" "$gen_date" "$gen_size" "$is_current" "$gen_path"
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

rollback_generation() {
	log_section "Rollback Generation"

	list_generations || return 1

	local gen_choice
	gen_choice=$(gum choose "$(get_generation_list)" --header "Select generation to rollback to:" --height 15)

	[[ -z "$gen_choice" ]] && {
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
	target_path="$(readlink -f "$target_gen")"

	log_warn "This will switch the system profile to generation $gen_num"
	log_info "Target: $target_path"

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

	log_warn "WARNING: Deleting generations is irreversible!"

	local keep_count
	keep_count=$(gum input --header "Keep last N generations:" --value "3" --char-limit=3)

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
	gum spin --title "Collecting garbage..." -- nix store --store "$MOUNTPOINT/nix/store" collect-garbage -d || {
		log_warn "Garbage collection had issues"
	}

	log_success "Deleted $delete_count generation(s)"

	return 0
}

view_generation_diff() {
	log_section "Generation Diff"

	list_generations || return 1

	local gen1_choice gen2_choice
	gen1_choice=$(gum choose "$(get_generation_list)" --header "Select first generation:" --height 15)
	[[ -z "$gen1_choice" ]] && return 1

	gen2_choice=$(gum choose "$(get_generation_list)" --header "Select second generation:" --height 15)
	[[ -z "$gen2_choice" ]] && return 1

	local gen1="${gen1_choice%% (*}"
	local gen2="${gen2_choice%% (*}"

	local gen1_path="$PROFILE_DIR/system-${gen1}-link"
	local gen2_path="$PROFILE_DIR/system-${gen2}-link"

	if [[ ! -L "$gen1_path" ]] || [[ ! -L "$gen2_path" ]]; then
		log_error "Invalid generation number(s)"
		return 1
	fi

	log_info "Comparing generation $gen1 → $gen2..."

	local path1 path2
	path1="$(readlink -f "$gen1_path")"
	path2="$(readlink -f "$gen2_path")"

	nix store --store "$MOUNTPOINT/nix/store" diff-closures "$path1" "$path2" | less

	return 0
}
