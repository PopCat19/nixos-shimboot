# merge.sh
#
# Purpose: Git merge utilities with automatic conflict resolution
#
# This module provides:
# - Automatic backup tag creation before merge
# - Merge with --theirs conflict resolution
# - Conflict detection and reporting
#
# shellcheck shell=bash

# Ensure script is sourced, not executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	echo "Error: merge.sh should be sourced, not executed" >&2
	exit 1
fi

# Create backup tag before merge
create_backup_tag() {
	local target_branch="$1"
	local backup_tag

	backup_tag="${target_branch}-$(date -u +'%Y%m%d-%H%M%S')"
	git tag -a "$backup_tag" -m "Backup before merge into ${target_branch}"
	log_info "Created backup tag: ${backup_tag}"
	echo "$backup_tag"
}

# Force merge with --theirs conflict resolution
merge_with_theirs() {
	local current_branch="$1"
	local target_branch="$2"

	log_warn "Auto-resolving conflicts by preferring incoming changes..."

	get_conflicted_files | while IFS= read -r file; do
		[[ -z "$file" ]] && continue
		if [[ ! -e "$file" ]]; then
			git rm -f "$file" 2>/dev/null || true
			continue
		fi
		if git ls-files -u -- "$file" 2>/dev/null | grep -q "^[0-9]* [0-9a-f]* 3"; then
			if git show ":3:$file" >"$file" 2>/dev/null; then
				git add "$file" && continue
			fi
		fi
		if git ls-files -u -- "$file" 2>/dev/null | grep -q "^[0-9]* [0-9a-f]* 2"; then
			git rm -f -- "$file" 2>/dev/null || true
			continue
		fi
		if git checkout --theirs -- "$file" 2>/dev/null; then
			git add -- "$file" 2>/dev/null && continue
		else
			log_warn "Could not auto-resolve: $file (resolve manually)"
		fi
	done

	# Clean up working tree
	git checkout -- . 2>/dev/null || true
	git clean -fd 2>/dev/null || true

	git commit -m "Merge branch '${current_branch}' into ${target_branch} (auto-resolved)"
	log_info "Merge completed with incoming changes preferred"
}

# Perform merge with automatic backup and conflict resolution
# Returns: 0 on success, 1 on failure
perform_merge() {
	local current_branch="$1"
	local target_branch="$2"
	local use_theirs="${3:-true}"

	# Create backup tag before merge
	local backup_tag
	backup_tag=$(create_backup_tag "$target_branch")

	# Build merge options
	local merge_opts="--no-ff"
	if [[ "$use_theirs" == "true" ]]; then
		merge_opts="--no-ff --strategy-option=theirs"
		log_info "Using --strategy-option=theirs (preferring incoming changes)"
	fi

	# Attempt merge
	# shellcheck disable=SC2086
	if ! git merge $merge_opts "$current_branch" -m "Merge branch '${current_branch}' into ${target_branch}"; then
		log_error "Merge conflicts detected"

		# Show conflict summary
		local conflict_count
		conflict_count=$(get_conflicted_files | wc -l)
		echo ""
		echo "Conflicting files ($conflict_count total):"
		echo "=================="
		get_conflicted_files | sed 's/^/  /'
		echo ""

		# Auto-resolve with --theirs if requested
		if [[ "$use_theirs" == "true" ]]; then
			log_info "Auto-resolving conflicts with --theirs..."
			merge_with_theirs "$current_branch" "$target_branch"
			return $?
		else
			log_warn "Backup tag created: $backup_tag"
			echo "Resolve conflicts manually, then:"
			echo "  1. git add <resolved-files>"
			echo "  2. git commit"
			echo ""
			echo "Or abort and retry:"
			echo "  git merge --abort"
			echo "  git reset --hard $backup_tag"
			return 1
		fi
	fi

	log_info "Merged ${current_branch} into ${target_branch}"
	return 0
}
