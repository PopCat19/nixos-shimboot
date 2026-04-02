#!/usr/bin/env bash
# propagate-changes.sh
#
# Purpose: Propagate default branch changes to popcat19-dev
# Usage: ./propagate-changes.sh [--push]
#
# Note: dev branch is base-only and does NOT auto-propagate to default.
# default is the source for popcat19-dev.

set -e

PUSH=0
if [ "$1" = "--push" ]; then
    PUSH=1
fi

echo "=== Propagating default branch changes to popcat19-dev ==="
echo ""

# Save current branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

cleanup() {
    echo ""
    echo "Cleaning up..."
    git checkout "$CURRENT_BRANCH" 2>/dev/null || true
}
trap cleanup EXIT

echo "1. Fetching latest changes..."
git fetch origin

echo ""
echo "2. Updating popcat19-dev branch from default..."
git checkout popcat19-dev
git merge origin/default --no-edit || {
    echo "ERROR: Merge failed on popcat19-dev branch"
    echo "Resolve conflicts manually, then run:"
    echo "  git add -A && git commit"
    exit 1
}

if [ $PUSH -eq 1 ]; then
    echo "Pushing popcat19-dev..."
    git push origin popcat19-dev
fi

echo ""
echo "=== Propagation complete ==="
echo ""
echo "Branch status:"
git log --oneline --graph default popcat19-dev | head -10

if [ $PUSH -eq 0 ]; then
    echo ""
    echo "To push changes, run: ./propagate-changes.sh --push"
fi
