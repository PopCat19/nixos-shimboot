#!/usr/bin/env bash
#
# generate-changelog.sh
#
# Purpose: Generate changelog from git history before merge
#
# This script:
# - Collects commits between target branch and current branch
# - Archives existing root changelogs
# - Generates a new changelog file
# - Optionally renames after merge with actual commit hash
#
# Usage:
#   ./generate-changelog.sh [OPTIONS]
#
# Options:
#   --target BRANCH    Target branch (prompts if not specified)
#   --rename           Rename pending changelog with current HEAD hash
#   --yes, -y          Skip all confirmation prompts
#   --help             Show this help message
#
# Examples:
#   # Interactive mode (prompts for target branch)
#   ./generate-changelog.sh
#
#   # Specify target branch
#   ./generate-changelog.sh --target dev
#
#   # Rename after merge
#   ./generate-changelog.sh --rename

set -Eeuo pipefail

# Determine project root (parent of conventions/ if script is in conventions/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ "$(basename "$SCRIPT_DIR")" == "conventions" ]]; then
	PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
else
	PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo ".")"
fi

# Default values
TARGET_BRANCH=""
RENAME_MODE=false
SKIP_CONFIRM=false
ARCHIVE_DIR="${PROJECT_ROOT}/changelog-archive"

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

log_prompt() {
	printf "${ANSI_CYAN}  ? %s${ANSI_CLEAR}" "$1"
}

show_help() {
	sed -n '/^# Purpose:/,/^$/p' "$0" | sed 's/^# //'
	exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
	case "$1" in
	--target)
		TARGET_BRANCH="$2"
		shift 2
		;;
	--rename)
		RENAME_MODE=true
		shift
		;;
	--yes | -y)
		SKIP_CONFIRM=true
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

# Rename mode: rename pending changelog with current HEAD hash
if [[ "$RENAME_MODE" == "true" ]]; then
	if [[ ! -f "${PROJECT_ROOT}/CHANGELOG-pending.md" ]]; then
		log_error "No CHANGELOG-pending.md found in project root"
		exit 1
	fi

	MERGE_HASH=$(git rev-parse --short HEAD)
	mv "${PROJECT_ROOT}/CHANGELOG-pending.md" "${PROJECT_ROOT}/CHANGELOG-${MERGE_HASH}.md"
	log_info "Renamed: CHANGELOG-pending.md → CHANGELOG-${MERGE_HASH}.md"
	echo ""
	echo "To amend the merge commit:"
	echo "  git add ${PROJECT_ROOT}/CHANGELOG-${MERGE_HASH}.md ${ARCHIVE_DIR}/"
	echo "  git commit --amend --no-edit"
	exit 0
fi

# Get current branch
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "detached")

if [[ "$CURRENT_BRANCH" == "detached" ]]; then
	log_error "Cannot generate changelog in detached HEAD state"
	exit 1
fi

# Get common branches for target selection
get_common_branches() {
	git branch -r 2>/dev/null | grep -E 'origin/(main|master|dev|develop|staging)' | sed 's/.*origin\///' | sort -u
}

# Prompt for target branch if not specified
if [[ -z "$TARGET_BRANCH" ]]; then
	COMMON_BRANCHES=$(get_common_branches)
	DEFAULT_BRANCH="main"

	# Try to detect default branch
	if echo "$COMMON_BRANCHES" | grep -q "^main$"; then
		DEFAULT_BRANCH="main"
	elif echo "$COMMON_BRANCHES" | grep -q "^master$"; then
		DEFAULT_BRANCH="master"
	fi

	echo ""
	echo "Available branches:"
	echo "$COMMON_BRANCHES" | head -5
	echo ""
	log_prompt "Target branch [${DEFAULT_BRANCH}] (q to quit): "
	read -r INPUT_BRANCH

	# Allow user to quit
	if [[ "$INPUT_BRANCH" == "q" || "$INPUT_BRANCH" == "quit" || "$INPUT_BRANCH" == "exit" ]]; then
		log_info "Aborted"
		exit 0
	fi

	TARGET_BRANCH="${INPUT_BRANCH:-$DEFAULT_BRANCH}"
fi

if [[ "$CURRENT_BRANCH" == "$TARGET_BRANCH" ]]; then
	log_error "Already on $TARGET_BRANCH, switch to feature branch"
	exit 1
fi

# Check for commits
COMMITS=$(git log "$TARGET_BRANCH..HEAD" --oneline --no-merges 2>/dev/null || true)

if [[ -z "$COMMITS" ]]; then
	log_error "No new commits relative to $TARGET_BRANCH"
	exit 1
fi

# Count commits
COMMIT_COUNT=$(echo "$COMMITS" | wc -l)
log_info "Found $COMMIT_COUNT commits to include in changelog"

# Show preview of commits
echo ""
echo "Commits to be included:"
echo "$COMMITS" | head -10
if [[ $COMMIT_COUNT -gt 10 ]]; then
	echo "  ... and $((COMMIT_COUNT - 10)) more"
fi
echo ""

# Ask for confirmation
if [[ "$SKIP_CONFIRM" != "true" ]]; then
	log_prompt "Generate changelog for ${COMMIT_COUNT} commits? [y/N] "
	read -n 1 -r
	echo ""
	if [[ ! $REPLY =~ ^[Yy]$ ]]; then
		log_info "Aborted"
		exit 0
	fi
fi

# Archive existing root changelogs (excluding pending which may exist from aborted run)
mkdir -p "$ARCHIVE_DIR"
for old in "${PROJECT_ROOT}"/CHANGELOG-*.md; do
	# Skip if no matches (glob returned literal pattern)
	[[ -e "$old" ]] || continue
	# Skip pending changelog - will be regenerated
	[[ "$(basename "$old")" == "CHANGELOG-pending.md" ]] && continue
	if [[ -f "$old" ]]; then
		mv "$old" "$ARCHIVE_DIR/"
		log_info "Archived: $(basename "$old") → changelog-archive/"
	fi
done

# Generate changelog
PLACEHOLDER="pending"
CHANGELOG="${PROJECT_ROOT}/CHANGELOG-${PLACEHOLDER}.md"

# Detect merge type based on branch relationship
MERGE_TYPE="Merge commit"
if git merge-base --is-ancestor "$TARGET_BRANCH" HEAD 2>/dev/null; then
	# Current branch is ahead of target (can fast-forward)
	MERGE_TYPE="Fast-forward"
fi

# Get remote URL for commit hyperlinks
REMOTE_URL=$(git remote get-url origin 2>/dev/null | sed 's/\.git$//' | sed 's/git@github\.com:/https:\/\/github.com\//')

# Format commits with hyperlinks
format_commits() {
	git log "$TARGET_BRANCH..HEAD" --no-merges --pretty=format:"%s|%h" 2>/dev/null | while IFS='|' read -r msg hash; do
		if [[ -n "$REMOTE_URL" ]]; then
			echo "- $msg ([\`$hash\`]($REMOTE_URL/commit/$hash))"
		else
			echo "- $msg (\`$hash\`)"
		fi
	done
}

log_info "Generating changelog: $CHANGELOG"

cat >"$CHANGELOG" <<EOF
# Changelog — ${CURRENT_BRANCH} → ${TARGET_BRANCH}

**Date:** $(date -u +"%Y-%m-%d")
**Branch:** ${CURRENT_BRANCH}
**Merge type:** ${MERGE_TYPE} (linear history)
**HEAD:** \`pending\` (rename after merge)

## Commits

$(format_commits)

## Files changed

\`\`\`
$(git diff --stat "$TARGET_BRANCH...HEAD" 2>/dev/null | head -100)
\`\`\`
EOF

log_info "Generated: $CHANGELOG"
echo ""
echo "Next steps:"
echo "  1. Review the changelog: cat $CHANGELOG"
echo "  2. Commit before merge: git add $CHANGELOG $ARCHIVE_DIR/"
echo "  3. After merge, rename: $0 --rename"
