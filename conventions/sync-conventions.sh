#!/usr/bin/env bash
#
# sync-conventions.sh
#
# Purpose: Sync dev-conventions files from remote repository
#
# This script downloads convention files from a source repository,
# allowing projects to stay synchronized with the latest conventions
# while maintaining git tracking in the target project.
#
# Usage:
#   ./sync-conventions.sh [OPTIONS]
#
# Options:
#   --remote URL       Source repository URL (default: https://github.com/PopCat19/dev-conventions)
#   --branch BRANCH    Branch to pull from (default: main)
#   --version HASH     Specific commit hash or tag (default: latest on branch)
#   --files LIST       Comma-separated list of files (default: all in conventions/)
#   --dry-run          Show what would be downloaded without writing
#   --no-commit        Skip auto-commit (only stage updated files)
#   --push             Auto-push after commit (default: false)
#   --help             Show this help message
#
# Examples:
#   # Pull latest from default remote
#   ./sync-conventions.sh
#
#   # Pull from specific branch
#   ./sync-conventions.sh --branch dev
#
#   # Pull specific version
#   ./sync-conventions.sh --version v1.2.0
#   ./sync-conventions.sh --version abc123
#
#   # Pull from custom remote
#   ./sync-conventions.sh --remote https://github.com/myfork/dev-conventions
#
#   # Pull specific files only
#   ./sync-conventions.sh --files conventions/AGENTS.md,conventions/DEVELOPMENT.md

set -Eeuo pipefail

# Cleanup function for .tmp files on error
cleanup_tmp() {
	for f in *.tmp; do
		[[ -f "$f" ]] && rm -f "$f"
	done
}
trap cleanup_tmp ERR

# Default values
DEFAULT_REMOTE="https://github.com/PopCat19/dev-conventions"
DEFAULT_BRANCH="main"
DEFAULT_FILES=("conventions/AGENTS.md" "conventions/DEVELOPMENT.md" "conventions/DEV-EXAMPLES.md" "conventions/generate-changelog.sh" "conventions/sync-conventions.sh")

REMOTE_URL=""
BRANCH=""
VERSION=""
FILES=()
DRY_RUN=false
AUTO_COMMIT=true
AUTO_PUSH=false

# Colors
ANSI_CLEAR='\033[0m'
ANSI_GREEN='\033[1;32m'
ANSI_YELLOW='\033[1;33m'
ANSI_RED='\033[1;31m'
ANSI_CYAN='\033[1;36m'

log_info() {
	printf "${ANSI_GREEN}  → %s${ANSI_CLEAR}\n" "$1"
}

log_warn() {
	printf "${ANSI_YELLOW}  ⚠ %s${ANSI_CLEAR}\n" "$1"
}

log_error() {
	printf "${ANSI_RED}  ✗ %s${ANSI_CLEAR}\n" "$1"
}

log_detail() {
	printf "${ANSI_CYAN}    %s${ANSI_CLEAR}\n" "$1"
}

show_help() {
	sed -n '/^# Purpose:/,/^$/p' "$0" | sed 's/^# //'
	exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
	case "$1" in
	--remote)
		REMOTE_URL="$2"
		shift 2
		;;
	--branch)
		BRANCH="$2"
		shift 2
		;;
	--version)
		VERSION="$2"
		shift 2
		;;
	--files)
		IFS=',' read -ra FILES <<<"$2"
		shift 2
		;;
	--dry-run)
		DRY_RUN=true
		shift
		;;
	--no-commit)
		AUTO_COMMIT=false
		shift
		;;
	--no-push)
		AUTO_PUSH=false
		shift
		;;
	--help | -h)
		show_help
		;;
	*)
		log_error "Unknown option: $1"
		exit 1
		;;
	esac
done

# Apply defaults
REMOTE_URL="${REMOTE_URL:-$DEFAULT_REMOTE}"
BRANCH="${BRANCH:-$DEFAULT_BRANCH}"
if [[ ${#FILES[@]} -eq 0 ]]; then
	FILES=("${DEFAULT_FILES[@]}")
fi

# Normalize remote URL for GitHub
normalize_url() {
	local url="$1"
	# Convert git@github.com: to https://
	url="${url/git@github\.com:/https:\/\/github.com\/}"
	# Remove .git suffix
	url="${url%.git}"
	echo "$url"
}

REMOTE_URL=$(normalize_url "$REMOTE_URL")

# Determine ref to fetch
if [[ -n "$VERSION" ]]; then
	REF="$VERSION"
else
	REF="$BRANCH"
fi

log_info "Syncing dev-conventions"
log_detail "Remote: $REMOTE_URL"
log_detail "Ref: $REF"
log_detail "Files: ${FILES[*]}"
echo ""

# Fetch files using curl from raw GitHub content
fetch_file() {
	local file="$1"
	local raw_url

	# Construct raw URL for GitHub
	if [[ "$REMOTE_URL" == https://github.com/* ]]; then
		local repo_path="${REMOTE_URL#https://github.com/}"
		raw_url="https://raw.githubusercontent.com/${repo_path}/${REF}/${file}"
	else
		log_error "Only GitHub repositories are supported currently"
		exit 1
	fi

	local content
	local http_code

	# Fetch with curl
	http_code=$(curl -sSL -w "%{http_code}" -o /tmp/sync-content "$raw_url" 2>/dev/null) || {
		log_error "Failed to fetch $file (curl error)"
		return 1
	}

	if [[ "$http_code" != "200" ]]; then
		log_error "Failed to fetch $file (HTTP $http_code)"
		return 1
	fi

	content=$(cat /tmp/sync-content)

	if [[ -z "$content" ]]; then
		log_warn "Empty content for $file"
		return 1
	fi

	echo "$content"
	return 0
}

# Track what was updated
UPDATED=()
SKIPPED=()
FAILED=()
NEEDS_COMMIT=()
SELF_UPDATED=false

for file in "${FILES[@]}"; do
	echo -e "${ANSI_CYAN}  Checking $file...${ANSI_CLEAR}"

	content=$(fetch_file "$file") || {
		FAILED+=("$file")
		continue
	}

	if [[ -f "$file" ]]; then
		existing=$(cat "$file")
		if [[ "$content" == "$existing" ]]; then
			# Content matches, but check if file needs git tracking
			if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
				if ! git ls-files --error-unmatch "$file" >/dev/null 2>&1; then
					# File is untracked
					log_detail "Untracked, will stage"
					NEEDS_COMMIT+=("$file")
				elif git diff --quiet "$file" 2>/dev/null; then
					# File is tracked and unchanged
					log_detail "Unchanged, skipping"
					SKIPPED+=("$file")
					continue
				else
					# File has uncommitted changes (content matches remote)
					log_detail "Has uncommitted changes, will stage"
					NEEDS_COMMIT+=("$file")
				fi
			else
				log_detail "Unchanged, skipping"
				SKIPPED+=("$file")
			fi
			continue
		fi
	fi

	if [[ "$DRY_RUN" == "true" ]]; then
		log_detail "Would update (dry-run)"
	else
		# Write to temp file first, then atomic move
		echo "$content" >"$file.tmp"
		# Preserve permissions if file exists
		if [[ -f "$file" ]]; then
			chmod --reference="$file" "$file.tmp" 2>/dev/null || true
		fi
		mv "$file.tmp" "$file"
		log_detail "Updated"

		# Track if script updated itself
		if [[ "$file" == "$(basename "$0")" ]]; then
			SELF_UPDATED=true
		fi
	fi
	UPDATED+=("$file")
	NEEDS_COMMIT+=("$file")
done

# Cleanup
rm -f /tmp/sync-content

# Summary
echo ""
log_info "Summary"
log_detail "Updated: ${#UPDATED[@]} files"
log_detail "Untracked/modified: $((${#NEEDS_COMMIT[@]} - ${#UPDATED[@]})) files"
log_detail "Skipped: ${#SKIPPED[@]} files (unchanged)"
log_detail "Failed: ${#FAILED[@]} files"

if [[ ${#UPDATED[@]} -gt 0 ]]; then
	echo ""
	log_info "Updated files:"
	for f in "${UPDATED[@]}"; do
		log_detail "$f"
	done
fi

if [[ ${#FAILED[@]} -gt 0 ]]; then
	echo ""
	log_warn "Failed files:"
	for f in "${FAILED[@]}"; do
		log_detail "$f"
	done
	exit 1
fi

if [[ "$DRY_RUN" == "true" ]]; then
	echo ""
	log_info "Dry-run complete, no files were modified"
elif [[ ${#NEEDS_COMMIT[@]} -eq 0 ]]; then
	echo ""
	log_info "No files need syncing"
else
	echo ""
	if [[ "$AUTO_COMMIT" == "true" ]]; then
		log_info "Auto-committing changes..."
		git add "${NEEDS_COMMIT[@]}"
		git commit -m "chore: sync dev-conventions"
		log_detail "Committed ${#NEEDS_COMMIT[@]} files"

		if [[ "$AUTO_PUSH" == "true" ]]; then
			log_info "Auto-pushing..."
			git push
			log_detail "Pushed to remote"
		fi
	else
		log_info "Files updated. Review changes and commit:"
		log_detail "git diff"
		log_detail "git add ${NEEDS_COMMIT[*]}"
		log_detail 'git commit -m "chore: sync dev-conventions"'
	fi
fi

# Warn if script updated itself
if [[ "$SELF_UPDATED" == "true" ]]; then
	echo ""
	log_warn "Script updated itself. Re-run to ensure consistency."
fi
