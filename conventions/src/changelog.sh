# changelog.sh
#
# Purpose: Changelog generation and merge workflow
#
# This module provides:
# - Changelog generation from git history
# - Merge workflow with automatic backup
# - State management for resumable operations
#
# shellcheck shell=bash

# Ensure script is sourced, not executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	echo "Error: changelog.sh should be sourced, not executed" >&2
	exit 1
fi

# State file for tracking merge progress
STATE_FILE="${PROJECT_ROOT}/.changelog-merge-state"
ARCHIVE_DIR="${PROJECT_ROOT}/changelog_archive"

# Cleanup function
cleanup_state() {
	rm -f "$STATE_FILE"
}

# Format commits with hyperlinks
format_commits() {
	local target_branch="$1"
	local commits
	commits=$(git log "$target_branch..HEAD" --no-merges --pretty=format:"%s|%h" 2>/dev/null) || return 0
	if [[ -z "$commits" ]]; then
		return 0
	fi
	while IFS='|' read -r msg hash; do
		if [[ -n "$msg" ]]; then
			if [[ -n "$REMOTE_URL" ]]; then
				echo "- $msg ([\`$hash\`]($REMOTE_URL/commit/$hash))"
			else
				echo "- $msg (\`$hash\`)"
			fi
		fi
	done <<<"$commits"
}

# Generate changelog file
generate_changelog() {
	local target_branch="$1"
	local current_branch="$2"
	local output_file="$3"

	# Detect merge type based on branch relationship
	local merge_type="Merge commit"
	if git merge-base --is-ancestor "$target_branch" HEAD 2>/dev/null; then
		merge_type="Fast-forward"
	fi

	log_info "Generating changelog: $output_file"

	cat >"$output_file" <<EOF
# Changelog -- ${current_branch} -> ${target_branch}

**Date:** $(date -u +"%Y-%m-%d")
**Branch:** ${current_branch}
**Merge type:** ${merge_type} (linear history)
**HEAD:** \`pending\` (rename after merge)

## Commits

$(format_commits "$target_branch")

## Files changed

\`\`\`
$(git diff --stat "$target_branch...HEAD" 2>/dev/null | head -100)
\`\`\`
EOF

	log_info "Generated: $(basename "$output_file")"
}

# Archive existing root changelogs
archive_changelogs() {
	mkdir -p "$ARCHIVE_DIR"
	for old in "${PROJECT_ROOT}"/CHANGELOG-*.md; do
		[[ -e "$old" ]] || continue
		[[ "$(basename "$old")" == "CHANGELOG-pending.md" ]] && continue
		if [[ -f "$old" ]]; then
			mv "$old" "$ARCHIVE_DIR/"
			log_info "Archived: $(basename "$old") -> changelog_archive/"
		fi
	done
}

# Rename pending changelog with current HEAD hash
rename_pending_changelog() {
	if [[ ! -f "${PROJECT_ROOT}/CHANGELOG-pending.md" ]]; then
		log_error "No CHANGELOG-pending.md found in project root"
		return 1
	fi

	local merge_hash
	merge_hash=$(git rev-parse --short HEAD)
	mv "${PROJECT_ROOT}/CHANGELOG-pending.md" "${PROJECT_ROOT}/CHANGELOG-${merge_hash}.md"
	log_info "Renamed: CHANGELOG-pending.md -> CHANGELOG-${merge_hash}.md"
	echo ""
	echo "To amend the merge commit:"
	echo "  git add ${PROJECT_ROOT}/CHANGELOG-${merge_hash}.md ${ARCHIVE_DIR}/"
	echo "  git commit --amend --no-edit"
}

# Handle stale state file
handle_stale_state() {
	log_warn "Found stale merge state file from previous run"

	local old_head
	old_head=$(grep "^HEAD=" "$STATE_FILE" 2>/dev/null | cut -d= -f2) || true

	if [[ -n "$old_head" && "$old_head" != "$(git rev-parse --short HEAD 2>/dev/null)" ]]; then
		log_warn "History has diverged since last run (HEAD changed)"
	fi

	log_prompt "[r]emove stale state and start fresh, [c]ontinue from saved state, or [a]bort? "
	read -n 1 -r
	echo ""
	case "$REPLY" in
	[Rr])
		cleanup_state
		rm -f "${PROJECT_ROOT}/CHANGELOG-pending.md" 2>/dev/null || true
		log_info "Removed stale state and pending changelog"
		;;
	[Cc])
		log_info "Continuing from saved state..."
		;;
	*)
		log_info "Aborted - remove state file manually to continue"
		exit 0
		;;
	esac
}

# Handle existing pending changelog
handle_pending_changelog() {
	log_warn "Found existing CHANGELOG-pending.md from previous run"
	log_prompt "[r]emove and start fresh, [c]omplete merge, or [a]bort? "
	read -n 1 -r
	echo ""
	case "$REPLY" in
	[Rr])
		rm -f "${PROJECT_ROOT}/CHANGELOG-pending.md"
		log_info "Removed existing pending changelog"
		;;
	[Cc])
		log_info "Completing previous merge..."
		local merge_hash
		merge_hash=$(git rev-parse --short HEAD)
		mv "${PROJECT_ROOT}/CHANGELOG-pending.md" "${PROJECT_ROOT}/CHANGELOG-${merge_hash}.md"
		log_info "Renamed: CHANGELOG-pending.md -> CHANGELOG-${merge_hash}.md"
		git add "CHANGELOG-${merge_hash}.md" "changelog_archive/" ".gitignore" 2>/dev/null || true
		if git log -1 --pretty=%s | grep -q "^Merge branch"; then
			git commit --amend --no-edit
			log_info "Amended merge commit with final changelog"
		else
			git commit -m "docs(changelog): add changelog for merge (${merge_hash})"
			log_info "Committed final changelog"
		fi
		exit 0
		;;
	*)
		log_info "Aborted - remove manually or use --rename to complete"
		exit 0
		;;
	esac
}

# Main changelog command
cmd_changelog() {
	local target_branch=""
	local rename_mode=false
	local generate_only=false
	local use_theirs=true # Default to --theirs for automatic conflict resolution

	# Parse arguments
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--target)
			target_branch="$2"
			shift 2
			;;
		--rename)
			rename_mode=true
			shift
			;;
		--generate-only)
			generate_only=true
			shift
			;;
		--theirs)
			use_theirs=true
			shift
			;;
		--no-theirs)
			use_theirs=false
			shift
			;;
		--yes | -y)
			# shellcheck disable=SC2034
			SKIP_CONFIRM=true
			shift
			;;
		*)
			log_error "Unknown option: $1"
			return 1
			;;
		esac
	done

	# Ensure state file is gitignored
	ensure_gitignored ".changelog-merge-state"

	# Handle rename mode
	if [[ "$rename_mode" == "true" ]]; then
		rename_pending_changelog
		return $?
	fi

	# Get current branch
	local current_branch
	current_branch=$(get_current_branch)

	if [[ "$current_branch" == "detached" ]]; then
		log_error "Cannot generate changelog in detached HEAD state"
		return 1
	fi

	# Check for incomplete merge
	if [[ -f ".git/MERGE_HEAD" ]]; then
		log_warn "Incomplete merge detected from previous run"
		log_info "Current merge in progress. Resolve or abort before continuing"
		return 1
	fi

	# Handle stale state
	if [[ -f "$STATE_FILE" && "$rename_mode" != "true" && "$generate_only" != "true" ]]; then
		handle_stale_state
	fi
	if [[ -f "${PROJECT_ROOT}/CHANGELOG-pending.md" && "$rename_mode" != "true" && "$generate_only" != "true" && ! -f "$STATE_FILE" ]]; then
		handle_pending_changelog
	fi

	# Prompt for target branch if not specified
	if [[ -z "$target_branch" ]]; then
		local common_branches
		common_branches=$(get_common_branches)
		local default_branch="main"

		if echo "$common_branches" | grep -q "^main$"; then
			default_branch="main"
		elif echo "$common_branches" | grep -q "^master$"; then
			default_branch="master"
		fi

		echo ""
		echo "Available branches:"

		local branch_array=()
		while IFS= read -r branch; do
			[[ -n "$branch" ]] && branch_array+=("$branch")
		done <<<"$common_branches"

		for i in "${!branch_array[@]}"; do
			local num=$((i + 1))
			local branch="${branch_array[$i]}"
			if [[ "$branch" == "$default_branch" ]]; then
				echo "  $num) $branch (default)"
			else
				echo "  $num) $branch"
			fi
		done
		echo ""

		log_prompt "Target branch number or name [${default_branch}] (q to quit): "
		local input_branch
		read -r input_branch

		if [[ "$input_branch" == "q" || "$input_branch" == "quit" || "$input_branch" == "exit" ]]; then
			log_info "Aborted"
			return 0
		fi

		if [[ "$input_branch" =~ ^[0-9]+$ ]]; then
			local idx=$((input_branch - 1))
			if [[ $idx -ge 0 && $idx -lt ${#branch_array[@]} ]]; then
				target_branch="${branch_array[$idx]}"
			else
				log_error "Invalid branch number: $input_branch"
				return 1
			fi
		else
			target_branch="${input_branch:-$default_branch}"
		fi
	fi

	if [[ "$current_branch" == "$target_branch" ]]; then
		log_error "Already on $target_branch, switch to feature branch"
		return 1
	fi

	# Check for commits
	local commits
	commits=$(git log "$target_branch..HEAD" --oneline --no-merges 2>/dev/null || true)

	if [[ -z "$commits" ]]; then
		log_error "No new commits relative to $target_branch"
		return 1
	fi

	# Count commits
	local commit_count
	commit_count=$(echo "$commits" | wc -l)
	log_info "Found $commit_count commits to include in changelog"

	# Show preview
	echo ""
	echo "Commits to be included:"
	echo "$commits" | head -10
	if [[ $commit_count -gt 10 ]]; then
		echo "  ... and $((commit_count - 10)) more"
	fi
	echo ""

	# Ask for confirmation
	if ! confirm "Generate changelog for ${commit_count} commits?"; then
		log_info "Aborted"
		return 0
	fi

	# Archive existing changelogs
	archive_changelogs

	# Generate changelog
	local changelog="${PROJECT_ROOT}/CHANGELOG-pending.md"
	REMOTE_URL=$(get_remote_url)
	generate_changelog "$target_branch" "$current_branch" "$changelog"

	# Generate-only mode
	if [[ "$generate_only" == "true" ]]; then
		echo ""
		echo "Next steps:"
		echo "  1. Review the changelog: cat $changelog"
		echo "  2. Commit before merge: git add $changelog $ARCHIVE_DIR/"
		echo "  3. After merge, rename: dev-conventions changelog --rename"
		return 0
	fi

	# Interactive merge workflow
	echo ""
	head -30 "$changelog"
	echo "  ..."
	echo ""

	# Step 1: Commit changelog
	if ! confirm "Commit changelog and merge ${current_branch} -> ${target_branch}?"; then
		echo ""
		echo "Changelog saved. Manual steps:"
		echo "  1. git add $changelog $ARCHIVE_DIR/"
		echo "  2. git commit -m \"docs(changelog): add changelog for ${current_branch} merge\""
		echo "  3. git checkout $target_branch && git merge $current_branch"
		echo "  4. dev-conventions changelog --rename"
		return 0
	fi

	git add "$changelog" "$ARCHIVE_DIR/" ".gitignore" 2>/dev/null || true
	git commit -m "docs(changelog): add changelog for ${current_branch} merge"
	log_info "Committed changelog on ${current_branch}"

	# Save state
	{
		echo "BRANCH=${current_branch}"
		echo "TARGET=${target_branch}"
		echo "HEAD=$(git rev-parse --short HEAD)"
		echo "STAGE=changelog_committed"
	} >"$STATE_FILE"

	# Step 2: Push feature branch
	if confirm "Push ${current_branch} to origin before merge?"; then
		git push origin "$current_branch"
		log_info "Pushed ${current_branch}"
	fi

	# Step 3: Switch to target branch
	log_info "Switching to ${target_branch}..."
	git checkout "$target_branch"
	git pull origin "$target_branch" 2>/dev/null || true

	# Step 4: Merge using merge module
	log_info "Merging ${current_branch} into ${target_branch}..."
	if ! perform_merge "$current_branch" "$target_branch" "$use_theirs"; then
		return 1
	fi

	# Update state
	if [[ -f "$STATE_FILE" ]]; then
		echo "STAGE=merged" >>"$STATE_FILE"
		echo "MERGE_HEAD=$(git rev-parse --short HEAD)" >>"$STATE_FILE"
	fi

	# Step 5: Rename changelog
	local merge_hash
	merge_hash=$(git rev-parse --short HEAD)
	local final_changelog="${PROJECT_ROOT}/CHANGELOG-${merge_hash}.md"
	mv "$changelog" "$final_changelog"
	log_info "Renamed: CHANGELOG-pending.md -> CHANGELOG-${merge_hash}.md"

	# Step 6: Amend merge commit
	cd "$PROJECT_ROOT" || exit 1
	git add "CHANGELOG-${merge_hash}.md" "CHANGELOG-pending.md" "changelog_archive/" 2>/dev/null || true
	git commit --amend --no-edit
	log_info "Amended merge commit with final changelog"

	# Verify working tree
	if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
		log_warn "Working tree has uncommitted changes after merge"
	fi

	# Step 7: Push
	if confirm "Push ${target_branch} to origin?"; then
		git push origin "$target_branch"
		log_info "Pushed ${target_branch}"
	fi

	echo ""
	log_info "Complete: ${current_branch} -> ${target_branch} (${merge_hash})"
	echo ""
	echo "  Changelog: CHANGELOG-${merge_hash}.md"
	echo "  Commit:    ${merge_hash}"

	# Cleanup
	cleanup_state
}
