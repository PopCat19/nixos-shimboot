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
#   --target BRANCH    Target branch (default: main)
#   --rename           Rename pending changelog with current HEAD hash
#   --help             Show this help message
#
# Examples:
#   # Generate changelog before merge
#   ./generate-changelog.sh --target dev
#
#   # Rename after merge
#   ./generate-changelog.sh --rename

set -Eeuo pipefail

# Default values
TARGET_BRANCH="main"
RENAME_MODE=false
ARCHIVE_DIR="changelog-archive"

# Colors
ANSI_CLEAR='\033[0m'
ANSI_GREEN='\033[1;32m'
ANSI_YELLOW='\033[1;33m'
ANSI_RED='\033[1;31m'

log_info() {
    printf "${ANSI_GREEN}  → %s${ANSI_CLEAR}\n" "$1"
}

log_warn() {
    printf "${ANSI_YELLOW}  ⚠ %s${ANSI_CLEAR}\n" "$1"
}

log_error() {
    printf "${ANSI_RED}  ✗ %s${ANSI_CLEAR}\n" "$1"
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
        --help|-h)
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
    if [[ ! -f "CHANGELOG-pending.md" ]]; then
        log_error "No CHANGELOG-pending.md found"
        exit 1
    fi

    MERGE_HASH=$(git rev-parse --short HEAD)
    mv "CHANGELOG-pending.md" "CHANGELOG-${MERGE_HASH}.md"
    log_info "Renamed: CHANGELOG-pending.md → CHANGELOG-${MERGE_HASH}.md"
    echo ""
    echo "To amend the merge commit:"
    echo "  git add CHANGELOG-${MERGE_HASH}.md ${ARCHIVE_DIR}/"
    echo "  git commit --amend --no-edit"
    exit 0
fi

# Get current branch
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "detached")

if [[ "$CURRENT_BRANCH" == "$TARGET_BRANCH" ]]; then
    log_error "Already on $TARGET_BRANCH, switch to feature branch"
    exit 1
fi

if [[ "$CURRENT_BRANCH" == "detached" ]]; then
    log_error "Cannot generate changelog in detached HEAD state"
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

# Archive existing root changelogs
mkdir -p "$ARCHIVE_DIR"
for old in CHANGELOG-*.md; do
    if [[ -f "$old" ]]; then
        mv "$old" "$ARCHIVE_DIR/"
        log_info "Archived: $old → $ARCHIVE_DIR/"
    fi
done

# Generate changelog
PLACEHOLDER="pending"
CHANGELOG="CHANGELOG-${PLACEHOLDER}.md"

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

cat > "$CHANGELOG" <<EOF
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
