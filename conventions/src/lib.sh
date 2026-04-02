# lib.sh
#
# Purpose: Shared utilities for dev-conventions tool
#
# shellcheck shell=bash
#
# This module provides:
# - Logging functions with ANSI colors
# - Interactive prompt helpers
# - Git helper functions
# - Common constants and defaults

# Ensure script is sourced, not executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	echo "Error: lib.sh should be sourced, not executed" >&2
	exit 1
fi

# Colors
ANSI_CLEAR='\033[0m'
ANSI_GREEN='\033[1;32m'
ANSI_YELLOW='\033[1;33m'
ANSI_RED='\033[1;31m'
ANSI_CYAN='\033[1;36m'
# shellcheck disable=SC2034
ANSI_BOLD='\033[1m'

# Logging functions
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

log_detail() {
	printf "${ANSI_CYAN}    %s${ANSI_CLEAR}\n" "$1"
}

log_success() {
	printf "${ANSI_GREEN}  ✓ %s${ANSI_CLEAR}\n" "$1"
}

# Prompt helpers
confirm() {
	local prompt="${1:-Continue?}"
	local default="${2:-n}"

	if [[ "$SKIP_CONFIRM" == "true" ]]; then
		return 0
	fi

	if [[ "$default" == "y" ]]; then
		log_prompt "$prompt [Y/n] "
	else
		log_prompt "$prompt [y/N] "
	fi
	read -n 1 -r
	echo ""

	[[ $REPLY =~ ^[Yy]$ ]] && return 0
	[[ -z "$REPLY" && "$default" == "y" ]] && return 0
	return 1
}

prompt_input() {
	local prompt="$1"
	local default="${2:-}"
	local result

	log_prompt "$prompt"
	[[ -n "$default" ]] && printf "[%s] " "$default"
	read -r result

	echo "${result:-$default}"
}

# Git helpers
get_current_branch() {
	git branch --show-current 2>/dev/null || echo "detached"
}

get_common_branches() {
	git branch -r 2>/dev/null | grep -E 'origin/(main|master|dev|develop|staging)' | sed 's/.*origin\///' | sort -u
}

get_remote_url() {
	git remote get-url origin 2>/dev/null | sed 's/\.git$//' | sed 's/git@github\.com:/https:\/\/github.com\//' || true
}

get_conflicted_files() {
	# ls-files -u lists all unmerged entries (covers renames, deletes, both-modified)
	git ls-files -u 2>/dev/null |
		awk '{$1=$2=$3=""; gsub(/^[[:space:]]+/,""); print}' |
		sort -u |
		grep -v '^$' || true
}

ensure_gitignored() {
	local pattern="$1"
	local gitignore="${PROJECT_ROOT:-.}/.gitignore"
	if [[ -f "$gitignore" ]]; then
		if ! grep -q "^${pattern}$" "$gitignore" 2>/dev/null; then
			echo "$pattern" >>"$gitignore"
			log_info "Added $pattern to .gitignore"
		fi
	else
		echo "$pattern" >"$gitignore"
		log_info "Created .gitignore with $pattern"
	fi
}

# Normalize GitHub URL
normalize_github_url() {
	local url="$1"
	url="${url/git@github\.com:/https:\/\/github.com\/}"
	url="${url%.git}"
	echo "$url"
}

# Check if command exists
command_exists() {
	command -v "$1" &>/dev/null
}

# Interactive choice menu using gum if available, otherwise basic prompt
# Usage: choose "option1    Description" "option2    Description"
# Returns: selected option (first word before whitespace)
choose() {
	local options=("$@")
	local selected

	if command_exists gum; then
		selected=$(gum choose "${options[@]}" --header="Select an option")
		# Extract just the option key (first word before whitespace)
		echo "$selected" | awk '{print $1}'
	else
		# Fallback: display numbered menu
		echo ""
		for i in "${!options[@]}"; do
			local num=$((i + 1))
			local opt="${options[$i]}"
			# Split on first whitespace to get key and description
			local key="${opt%%[[:space:]]*}"
			local desc="${opt#*[[:space:]]}"
			[[ "$key" == "$desc" ]] && desc=""
			printf "  %s) %s\n" "$num" "${desc:-$key}"
		done
		echo ""
		log_prompt "Select option [1-${#options[@]}]: "
		read -n 1 -r
		echo ""
		if [[ "$REPLY" =~ ^[0-9]+$ ]] && [[ "$REPLY" -ge 1 ]] && [[ "$REPLY" -le ${#options[@]} ]]; then
			local idx=$((REPLY - 1))
			local opt="${options[$idx]}"
			echo "${opt%%[[:space:]]*}"
		else
			return 1
		fi
	fi
}
