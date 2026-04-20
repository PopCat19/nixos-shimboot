# sync.sh
#
# Purpose: Sync dev-conventions files from remote repository
#
# This module provides:
# - File downloading from GitHub repositories
# - Change detection and git tracking
# - Auto-commit and push functionality
#
# shellcheck shell=bash

# Ensure script is sourced, not executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	echo "Error: sync.sh should be sourced, not executed" >&2
	exit 1
fi

# Default values
DEFAULT_REMOTE="https://github.com/PopCat19/dev-conventions"
DEFAULT_BRANCH="main"

# Build default files list dynamically
# Discovers all .md files in conventions/ plus shell scripts in conventions/src/
build_default_files() {
	local files=()

	# Discover all .md files in conventions/ (non-recursive)
	local md_files
	mapfile -t md_files < <(find conventions -maxdepth 1 -name "*.md" -type f 2>/dev/null | sort)
	files+=("${md_files[@]}")

	# Add shell scripts (fixed set - these are the CLI components)
	files+=(
		"conventions/dev-conventions.sh"
		"conventions/src/lib.sh"
		"conventions/src/merge.sh"
		"conventions/src/changelog.sh"
		"conventions/src/sync.sh"
		"conventions/src/lint.sh"
		"conventions/src/check-context.sh"
	)

	echo "${files[@]}"
}

DEFAULT_FILES=()
# shellcheck disable=SC2034
read -ra DEFAULT_FILES <<<"$(build_default_files)"

# Fetch file from GitHub (tries raw URL first, falls back to API)
fetch_file() {
	local file="$1"
	local remote_url="$2"
	local ref="$3"
	local repo_path

	# Extract repo path from GitHub URL
	if [[ "$remote_url" == https://github.com/* ]]; then
		repo_path="${remote_url#https://github.com/}"
	else
		log_error "Only GitHub repositories are supported currently"
		return 1
	fi

	# Try raw.githubusercontent.com first (faster)
	local raw_url="https://raw.githubusercontent.com/${repo_path}/${ref}/${file}"
	local http_code

	http_code=$(curl -sSL -w "%{http_code}" -o /tmp/sync-content "$raw_url" 2>/dev/null) || true

	if [[ "$http_code" == "200" ]]; then
		local content
		content=$(cat /tmp/sync-content)
		if [[ -n "$content" ]]; then
			echo "$content"
			return 0
		fi
	fi

	# Fallback: Use GitHub API (works when raw.githubusercontent.com is blocked)
	log_detail "Raw URL unavailable, using API..." >&2
	local api_url="https://api.github.com/repos/${repo_path}/contents/${file}?ref=${ref}"

	# Save response to file to avoid shell interpretation issues
	curl -sSL "$api_url" -o /tmp/sync-api-response.json 2>/dev/null || {
		log_error "Failed to fetch $file (API request failed)"
		return 1
	}

	# Check for API error
	if grep -q '"message"' /tmp/sync-api-response.json; then
		local error_msg
		error_msg=$(grep -oP '"message"\s*:\s*"\K[^"]+' /tmp/sync-api-response.json | head -1)
		log_error "Failed to fetch $file: $error_msg"
		return 1
	fi

	# Extract and decode base64 content
	# Prefer jq for proper JSON handling, fall back to grep/sed
	local content
	if command -v jq &>/dev/null; then
		content=$(jq -r '.content' /tmp/sync-api-response.json 2>/dev/null | base64 -d 2>/dev/null) || {
			log_error "Failed to decode content for $file"
			return 1
		}
	else
		# Fallback: extract content field and decode
		# Note: This may have issues with special characters
		local content_b64
		content_b64=$(grep -oP '"content"\s*:\s*"\K[^"]+' /tmp/sync-api-response.json 2>/dev/null)
		if [[ -z "$content_b64" ]]; then
			log_error "Failed to extract content from API response for $file"
			return 1
		fi
		content=$(printf '%s' "$content_b64" | base64 -d 2>/dev/null) || {
			log_error "Failed to decode base64 content for $file"
			return 1
		}
	fi

	if [[ -z "$content" ]]; then
		log_warn "Empty content for $file"
		return 1
	fi

	echo "$content"
	return 0
}

# Get file SHA from GitHub API for change detection
get_file_sha() {
	local file="$1"
	local remote_url="$2"
	local ref="$3"
	local repo_path

	if [[ "$remote_url" == https://github.com/* ]]; then
		repo_path="${remote_url#https://github.com/}"
	else
		return 1
	fi

	local api_url="https://api.github.com/repos/${repo_path}/contents/${file}?ref=${ref}"
	local response
	response=$(curl -sSL "$api_url" 2>/dev/null) || return 1

	# Extract SHA using jq or grep
	local sha
	if command -v jq &>/dev/null; then
		sha=$(jq -r '.sha' <<<"$response" 2>/dev/null)
	else
		sha=$(grep -oP '"sha"\s*:\s*"\K[^"]+' <<<"$response" 2>/dev/null)
	fi

	if [[ -n "$sha" && "$sha" != "null" ]]; then
		echo "$sha"
		return 0
	fi
	return 1
}

# Get cached SHA for a file
get_cached_sha() {
	local file="$1"
	local cache_dir=".dev-conventions-sync-cache"
	local cache_file="${cache_dir}/${file}.sha"

	if [[ -f "$cache_file" ]]; then
		printf '%s' "$(cat "$cache_file")"
		return 0
	fi
	return 1
}

# Save SHA to cache
save_sha_cache() {
	local file="$1"
	local sha="$2"
	local cache_dir=".dev-conventions-sync-cache"
	local cache_file="${cache_dir}/${file}.sha"

	# Create directory structure if needed (e.g., conventions/ subdir)
	mkdir -p "$(dirname "$cache_file")"
	printf '%s' "$sha" >"$cache_file"
}

# Create a backup branch with timestamp
create_git_backup() {
	local current_branch
	current_branch=$(get_current_branch)
	local timestamp
	timestamp=$(date +%Y%m%d%H%M%S)
	local backup_branch="${current_branch}_${timestamp}"

	if git branch "$backup_branch" 2>/dev/null; then
		log_detail "Backup branch created: $backup_branch"
		return 0
	fi
	return 1
}

# Consolidate subsequent linear dev-convention commits
consolidate_dev_commits() {
	local commit_msg="chore: sync dev-conventions"
	local count=0

	# Check how many subsequent commits have the exact same message
	while true; do
		local idx=$((count))
		local msg
		msg=$(git log -1 --format=%s "HEAD~${idx}" 2>/dev/null) || break
		if [[ "$msg" == "$commit_msg" ]]; then
			count=$((count + 1))
		else
			break
		fi
	done

	if [[ $count -gt 1 ]]; then
		log_info "Consolidating $count subsequent dev-convention commits..."

		# Create backup branch before dangerous operation
		create_git_backup

		# Soft reset to the commit before the sequence
		if git reset --soft "HEAD~${count}"; then
			if git commit -m "$commit_msg"; then
				log_success "Consolidated into a single commit"
				return 0
			fi
		fi
		log_error "Failed to consolidate commits"
		return 1
	fi
	return 1
}

# Main sync command
cmd_sync() {
	local remote_url=""
	local branch=""
	local version=""
	local files=()
	local dry_run=false
	local auto_commit=true
	local auto_push=false
	local consolidate=false

	# Ensure cache directory exists
	mkdir -p ".dev-conventions-sync-cache"

	# Parse arguments
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--remote)
			remote_url="$2"
			shift 2
			;;
		--branch)
			branch="$2"
			shift 2
			;;
		--version)
			version="$2"
			shift 2
			;;
		--files)
			IFS=',' read -ra files <<<"$2"
			shift 2
			;;
		--dry-run)
			dry_run=true
			shift
			;;
		--no-commit)
			auto_commit=false
			shift
			;;
		--no-push)
			auto_push=false
			shift
			;;
		--push)
			auto_push=true
			shift
			;;
		--consolidate)
			consolidate=true
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

	# Apply defaults
	remote_url="${remote_url:-$DEFAULT_REMOTE}"
	branch="${branch:-$DEFAULT_BRANCH}"
	if [[ ${#files[@]} -eq 0 ]]; then
		files=("${DEFAULT_FILES[@]}")
	fi

	# Normalize remote URL
	remote_url=$(normalize_github_url "$remote_url")

	# Determine ref to fetch
	local ref
	if [[ -n "$version" ]]; then
		ref="$version"
	else
		ref="$branch"
	fi

	log_info "Syncing dev-conventions"
	log_detail "Remote: $remote_url"
	log_detail "Ref: $ref"
	log_detail "Files: ${files[*]}"
	echo ""

	# Track what was updated
	local updated=()
	local skipped=()
	local failed=()
	local needs_commit=()
	local self_updated=false

	for file in "${files[@]}"; do
		echo -e "${ANSI_CYAN}  Checking $file...${ANSI_CLEAR}"

		local cached_sha remote_sha=""
		cached_sha=$(get_cached_sha "$file") || cached_sha=""

		remote_sha=$(get_file_sha "$file" "$remote_url" "$ref") || {
			log_detail "Could not get SHA for $file, falling back to content diff"
		}

		if [[ -n "$remote_sha" && "$remote_sha" == "$cached_sha" ]]; then
			log_detail "Unchanged (SHA cache hit), skipping"
			skipped+=("$file")
			continue
		fi

		local content
		if ! content=$(fetch_file "$file" "$remote_url" "$ref"); then
			failed+=("$file")
			continue
		fi

		if [[ -f "$file" ]] && diff -q <(cat "$file") <(echo "$content") >/dev/null 2>&1; then
			if [[ -n "$remote_sha" ]]; then
				save_sha_cache "$file" "$remote_sha"
			fi

			local is_tracked=false
			git ls-files --error-unmatch "$file" >/dev/null 2>&1 && is_tracked=true

			if [[ "$is_tracked" == "true" ]] && git diff --quiet "$file" 2>/dev/null; then
				log_detail "Unchanged, skipping"
				skipped+=("$file")
				continue
			else
				log_detail "Needs staging"
				needs_commit+=("$file")
			fi
			continue
		fi

		if [[ "$dry_run" == "true" ]]; then
			log_detail "Would update (dry-run)"
		else
			echo "$content" >"$file.tmp"
			if [[ -f "$file" ]]; then
				chmod --reference="$file" "$file.tmp" 2>/dev/null || true
			fi
			mv "$file.tmp" "$file"
			log_detail "Updated"

			if [[ -n "$remote_sha" ]]; then
				save_sha_cache "$file" "$remote_sha"
			fi

			if [[ "$file" == "conventions/dev-conventions.sh" ]]; then
				self_updated=true
			fi
		fi
		updated+=("$file")
		needs_commit+=("$file")
	done

	# Cleanup
	rm -f /tmp/sync-content

	# Summary
	echo ""
	log_info "Summary"
	log_detail "Updated: ${#updated[@]} files"
	log_detail "Untracked/modified: $((${#needs_commit[@]} - ${#updated[@]})) files"
	log_detail "Skipped: ${#skipped[@]} files (unchanged)"
	log_detail "Failed: ${#failed[@]} files"

	if [[ ${#updated[@]} -gt 0 ]]; then
		echo ""
		log_info "Updated files:"
		for f in "${updated[@]}"; do
			log_detail "$f"
		done
	fi

	if [[ ${#failed[@]} -gt 0 ]]; then
		echo ""
		log_warn "Failed files:"
		for f in "${failed[@]}"; do
			log_detail "$f"
		done
		return 1
	fi

	if [[ "$dry_run" == "true" ]]; then
		echo ""
		log_info "Dry-run complete, no files were modified"
	else
		local cache_dirty=false
		if [[ -n "$(git status --porcelain .dev-conventions-sync-cache/ 2>/dev/null)" ]]; then
			cache_dirty=true
		fi

		if [[ ${#needs_commit[@]} -eq 0 && "$cache_dirty" == "false" ]]; then
			echo ""
			log_info "No files need syncing"
		else
			echo ""
			if [[ "$auto_commit" == "true" ]]; then
				log_info "Auto-committing changes..."
				git add conventions/
				# Gracefully handle if sync cache is ignored or missing
				git add .dev-conventions-sync-cache/ 2>/dev/null || true

				if git diff --cached --quiet; then
					log_detail "No changes to commit"
				else
					git commit -m "chore: sync dev-conventions"
					log_detail "Committed ${#needs_commit[@]} files"
				fi

				local history_changed=false
				if [[ "$consolidate" == "true" ]]; then
					if consolidate_dev_commits; then
						history_changed=true
					fi
				fi

				if [[ "$auto_push" == "true" ]]; then
					# Check if remote exists and has an upstream configured
					local current_branch
					current_branch=$(get_current_branch)
					local has_remote=false
					local has_upstream=false

					if git remote >/dev/null 2>&1; then
						has_remote=true
						if git rev-parse --abbrev-ref "${current_branch}@{u}" >/dev/null 2>&1; then
							has_upstream=true
						fi
					fi

					if [[ "$has_remote" == "true" ]]; then
						# Check for uncommitted changes outside of conventions/
						local dirty_files
						dirty_files=$(git status --porcelain 2>/dev/null | grep -vE "^.. (conventions/|\.dev-conventions-sync-cache/)" || true)
						if [[ -n "$dirty_files" ]]; then
							log_warn "Uncommitted changes found outside of conventions/. Skipping push for safety."
							log_detail "Dirty files:\n$dirty_files"
							return 0
						fi

						if [[ "$has_upstream" == "true" ]]; then
							log_info "Pulling latest changes..."
							if ! git pull --rebase --quiet; then
								log_error "Pull failed. Please resolve conflicts manually."
								return 1
							fi

							log_info "Auto-pushing..."
							local push_args=()
							if [[ "$history_changed" == "true" ]]; then
								if [[ "$SKIP_CONFIRM" == "true" ]]; then
									push_args+=(--force-with-lease)
									log_warn "Using force-with-lease due to consolidation (--yes provided)"
								else
									log_warn "History changed due to consolidation but --yes not provided. Skipping push."
									log_detail "Hint: Run 'git push --force-with-lease' manually"
									return 0
								fi
							fi

							if git push "${push_args[@]}"; then
								log_detail "Pushed to remote"
							else
								log_warn "Push failed (check network or permissions)"
							fi
						else
							log_warn "No upstream branch configured for $current_branch, skipping push"
							log_detail "Hint: Run 'git push -u origin $current_branch' manually"
						fi
					else
						log_detail "No remote configured, skipping push"
					fi
				fi
			else
				log_info "Files updated. Review changes and commit:"
				log_detail "git diff"
				log_detail "git add ${needs_commit[*]}"
				log_detail 'git commit -m "chore: sync dev-conventions"'
			fi
		fi
	fi

	# Warn if script updated itself
	if [[ "$self_updated" == "true" ]]; then
		echo ""
		log_warn "Script updated itself. Re-run to ensure consistency."
	fi
}
