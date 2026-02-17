#!/usr/bin/env bash
#
# dev-conventions.sh
#
# Purpose: Unified CLI for development conventions tooling
#
# This script provides:
# - Changelog generation and merge workflow
# - Convention file syncing from remote
# - Shell script linting and formatting
# - Pre-push hook management
#
# Usage:
#   dev-conventions <command> [options]
#
# Commands:
#   changelog    Generate changelog and manage merge workflow
#   sync         Sync convention files from remote repository
#   lint         Format and check shell scripts
#   version      Show version information
#   help         Show this help message
#
# Examples:
#   # Generate changelog interactively
#   dev-conventions changelog
#
#   # Sync from specific branch
#   dev-conventions sync --branch dev
#
#   # Format all shell scripts
#   dev-conventions lint --format
#
#   # Install pre-push hook
#   dev-conventions lint --install-hook

set -Eeuo pipefail

# Determine script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="${SCRIPT_DIR}/src"

# Set PROJECT_ROOT for modules
if [[ "$(basename "$SCRIPT_DIR")" == "conventions" ]]; then
	PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
else
	PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo ".")"
fi
export PROJECT_ROOT

# Version
VERSION="0.1.0"
# shellcheck disable=SC2034
export SKIP_CONFIRM=false

# Source modules
source "${SRC_DIR}/lib.sh"
source "${SRC_DIR}/merge.sh"
source "${SRC_DIR}/changelog.sh"
source "${SRC_DIR}/sync.sh"
source "${SRC_DIR}/lint.sh"

# Show main help
show_main_help() {
	cat <<'EOF'
dev-conventions - Unified CLI for development conventions tooling

Usage:
  dev-conventions <command> [options]

Commands:
  changelog    Generate changelog and manage merge workflow
  sync         Sync convention files from remote repository
  lint         Format and check shell scripts
  version      Show version information
  help         Show this help message

Command Help:
  dev-conventions <command> --help

Examples:
  # Generate changelog interactively
  dev-conventions changelog

  # Sync from specific branch
  dev-conventions sync --branch dev

  # Format all shell scripts
  dev-conventions lint --format

  # Install pre-push hook
  dev-conventions lint --install-hook
EOF
}

# Show command help
show_command_help() {
	local cmd="$1"
	case "$cmd" in
	changelog)
		cat <<'EOF'
changelog - Generate changelog and manage merge workflow

Usage:
  dev-conventions changelog [options]

Options:
  --target BRANCH    Target branch (prompts if not specified)
  --rename           Rename pending changelog with current HEAD hash
  --generate-only    Generate changelog without merge workflow
  --theirs           Auto-resolve conflicts preferring incoming (default)
  --no-theirs        Disable auto-conflict resolution
  --yes, -y          Skip all confirmation prompts
  --help             Show this help message

Examples:
  # Interactive mode (prompts for target branch)
  dev-conventions changelog

  # Specify target branch
  dev-conventions changelog --target dev

  # Full automated merge (no prompts)
  dev-conventions changelog --target dev --yes

  # Rename after merge
  dev-conventions changelog --rename
EOF
		;;
	sync)
		cat <<'EOF'
sync - Sync convention files from remote repository

Usage:
  dev-conventions sync [options]

Options:
  --remote URL       Source repository URL (default: https://github.com/PopCat19/dev-conventions)
  --branch BRANCH    Branch to pull from (default: main)
  --version HASH     Specific commit hash or tag (default: latest on branch)
  --files LIST       Comma-separated list of files (default: all in conventions/)
  --dry-run          Show what would be downloaded without writing
  --no-commit        Skip auto-commit (only stage updated files)
  --push             Auto-push after commit (default: false)
  --help             Show this help message

Examples:
  # Pull latest from default remote
  dev-conventions sync

  # Pull from specific branch
  dev-conventions sync --branch dev

  # Pull specific version
  dev-conventions sync --version v1.2.0

  # Pull from custom remote
  dev-conventions sync --remote https://github.com/myfork/dev-conventions

  # Pull specific files only
  dev-conventions sync --files conventions/AGENTS.md,conventions/DEVELOPMENT.md
EOF
		;;
	lint)
		cat <<'EOF'
lint - Format and check shell scripts

Usage:
  dev-conventions lint [options]

Options:
  --check, -c        Check formatting without modifying (default)
  --format, -f       Format files in place
  --fix              Run both format and auto-fix what's possible
  --files LIST       Comma-separated list of files (default: all *.sh in project)
  --install-hook     Install pre-push hook for automatic linting
  --remove-hook      Remove pre-push hook
  --help             Show this help message

Examples:
  # Check all shell scripts
  dev-conventions lint

  # Format all shell scripts
  dev-conventions lint --format

  # Check specific files
  dev-conventions lint --files script.sh,lib/utils.sh

  # Install pre-push hook
  dev-conventions lint --install-hook
EOF
		;;
	*)
		echo "No help available for command: $cmd"
		;;
	esac
}

# Main TUI mode - interactive menu using gum
main_tui() {
	local options=(
		"changelog    Generate changelog and manage merge workflow"
		"sync         Sync convention files from remote repository"
		"lint         Format and check shell scripts"
		"version      Show version information"
		"help         Show this help message"
	)

	local choice
	choice=$(gum choose "${options[@]}" --header="dev-conventions" --header.foreground="cyan")

	if [[ -n "$choice" ]]; then
		# Extract command (first word)
		local cmd="${choice%%[[:space:]]*}"
		# Re-run main with the selected command
		main "$cmd"
	fi
}

# Main entrypoint
main() {
	# If no arguments, check for gum and launch TUI
	if [[ $# -eq 0 ]]; then
		if command_exists gum; then
			main_tui
			return
		else
			show_main_help
			return
		fi
	fi

	local cmd="${1:-help}"
	shift || true

	case "$cmd" in
	changelog)
		if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
			show_command_help "changelog"
			exit 0
		fi
		cmd_changelog "$@"
		;;
	sync)
		if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
			show_command_help "sync"
			exit 0
		fi
		cmd_sync "$@"
		;;
	lint)
		if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
			show_command_help "lint"
			exit 0
		fi
		cmd_lint "$@"
		;;
	version | --version | -v)
		echo "dev-conventions v${VERSION}"
		;;
	help | --help | -h)
		show_main_help
		;;
	*)
		log_error "Unknown command: $cmd"
		echo ""
		show_main_help
		exit 1
		;;
	esac
}

# Run main with all arguments
main "$@"
