#!/usr/bin/env bash
# propagate-dev.sh
#
# Purpose: Propagate dev branch changes to default and popcat19-dev
# Usage: ./propagate-dev.sh [--push]

set -e

PUSH=0
if [ "$1" = "--push" ]; then
    PUSH=1
fi

echo "=== Propagating dev branch changes ==="
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
echo "2. Updating default branch..."
git checkout default
git rebase origin/dev || {
    echo "ERROR: Rebase failed on default branch"
    echo "Resolve conflicts manually, then run:"
    echo "  git add -A && git rebase --continue"
    exit 1
}

if [ $PUSH -eq 1 ]; then
    echo "Pushing default..."
    git push --force-with-lease origin default
fi

echo ""
echo "3. Updating popcat19-dev branch..."
git checkout popcat19-dev
git rebase origin/default || {
    echo "ERROR: Rebase failed on popcat19-dev branch"
    echo "Resolve conflicts manually, then run:"
    echo "  git add -A && git rebase --continue"
    exit 1
}

if [ $PUSH -eq 1 ]; then
    echo "Pushing popcat19-dev..."
    git push --force-with-lease origin popcat19-dev
fi

echo ""
echo "=== Propagation complete ==="
echo ""
echo "Branch status:"
git log --oneline --graph --all | head -10

if [ $PUSH -eq 0 ]; then
    echo ""
    echo "To push changes, run: ./propagate-dev.sh --push"
fi
