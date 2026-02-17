# lint.sh
#
# Purpose: Shell script linting and formatting utilities
#
# This module provides:
# - shfmt formatting for shell scripts
# - shellcheck static analysis
# - Pre-push hook management
#
# shellcheck shell=bash

# Ensure script is sourced, not executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	echo "Error: lint.sh should be sourced, not executed" >&2
	exit 1
fi

# Find shell scripts in project
find_shell_scripts() {
	local root="${1:-.}"
	find "$root" -name "*.sh" -type f 2>/dev/null | grep -v node_modules | grep -v ".git"
}

# Run shfmt on files
run_shfmt() {
	local mode="$1"
	shift
	local files=("$@")

	if ! command_exists shfmt; then
		log_error "shfmt not found. Install: https://github.com/mvdan/sh"
		return 1
	fi

	local args=()
	if [[ "$mode" == "check" ]]; then
		args+=(-d)
	elif [[ "$mode" == "format" ]]; then
		args+=(-w)
	fi

	# Use shfmt defaults (tab indent, 80 width is common but we use default)
	local failed=0
	for file in "${files[@]}"; do
		if [[ "$mode" == "check" ]]; then
			if ! shfmt -d "$file" 2>/dev/null; then
				log_warn "Needs formatting: $file"
				((failed++)) || true
			fi
		else
			shfmt -w "$file" 2>/dev/null && log_detail "Formatted: $file"
		fi
	done

	if [[ $failed -gt 0 ]]; then
		return 1
	fi
	return 0
}

# Run shellcheck on files
run_shellcheck() {
	local mode="$1"
	shift
	local files=("$@")

	if ! command_exists shellcheck; then
		log_error "shellcheck not found. Install: https://www.shellcheck.net/"
		return 1
	fi

	local failed=0
	for file in "${files[@]}"; do
		if ! shellcheck "$file" 2>/dev/null; then
			log_warn "Issues found in: $file"
			((failed++)) || true
		else
			log_detail "OK: $file"
		fi
	done

	if [[ $failed -gt 0 ]]; then
		return 1
	fi
	return 0
}

# Install pre-push hook
install_pre_push_hook() {
	local hook_dir="${PROJECT_ROOT}/.git/hooks"
	local hook_file="$hook_dir/pre-push"

	if [[ ! -d "$hook_dir" ]]; then
		log_error "Not a git repository or .git/hooks not found"
		return 1
	fi

	# Check if hook already exists
	if [[ -f "$hook_file" ]]; then
		if grep -q "dev-conventions lint" "$hook_file" 2>/dev/null; then
			log_info "Pre-push hook already installed"
			return 0
		fi
		log_warn "Existing pre-push hook found. Appending dev-conventions check."
	fi

	# Create or append to hook
	local hook_content='
# dev-conventions pre-push check
if command -v dev-conventions &>/dev/null; then
    echo "Running dev-conventions lint..."
    dev-conventions lint --check || {
        echo "Lint check failed. Fix issues before pushing."
        exit 1
    }
fi
'

	if [[ -f "$hook_file" ]]; then
		echo "$hook_content" >>"$hook_file"
	else
		cat >"$hook_file" <<'EOF'
#!/usr/bin/env bash
# Pre-push hook for dev-conventions
EOF
		echo "$hook_content" >>"$hook_file"
		chmod +x "$hook_file"
	fi

	log_info "Installed pre-push hook: $hook_file"
}

# Remove pre-push hook
remove_pre_push_hook() {
	local hook_file="${PROJECT_ROOT}/.git/hooks/pre-push"

	if [[ ! -f "$hook_file" ]]; then
		log_info "No pre-push hook found"
		return 0
	fi

	# Check if it's our hook
	if grep -q "dev-conventions lint" "$hook_file" 2>/dev/null; then
		# Remove our section
		local temp_file
		temp_file=$(mktemp)
		sed '/# dev-conventions pre-push check/,/^fi$/d' "$hook_file" >"$temp_file"

		# If file is now just the shebang, remove it entirely
		if [[ $(wc -l <"$temp_file") -le 2 ]]; then
			rm -f "$hook_file"
			log_info "Removed pre-push hook (was only dev-conventions)"
		else
			mv "$temp_file" "$hook_file"
			log_info "Removed dev-conventions section from pre-push hook"
		fi
		rm -f "$temp_file"
	else
		log_info "Pre-push hook exists but not managed by dev-conventions"
	fi
}

# Main lint command
cmd_lint() {
	local mode="check"
	local files=()
	local install_hook=false
	local remove_hook=false

	# Parse arguments
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--format | -f)
			mode="format"
			shift
			;;
		--check | -c | --quick | -q)
			mode="check"
			shift
			;;
		--fix)
			mode="fix"
			shift
			;;
		--files)
			IFS=',' read -ra files <<<"$2"
			shift 2
			;;
		--install-hook)
			install_hook=true
			shift
			;;
		--remove-hook)
			remove_hook=true
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

	# Handle hook operations
	if [[ "$install_hook" == "true" ]]; then
		install_pre_push_hook
		return $?
	fi

	if [[ "$remove_hook" == "true" ]]; then
		remove_pre_push_hook
		return $?
	fi

	# Find shell scripts if not specified
	if [[ ${#files[@]} -eq 0 ]]; then
		mapfile -t files < <(find_shell_scripts "$PROJECT_ROOT")
	fi

	if [[ ${#files[@]} -eq 0 ]]; then
		log_warn "No shell scripts found in $PROJECT_ROOT"
		return 0
	fi

	log_info "Found ${#files[@]} shell script(s)"
	echo ""

	local shfmt_failed=0
	local shellcheck_failed=0

	# Run shfmt
	log_info "Running shfmt ($mode)..."
	if ! run_shfmt "$mode" "${files[@]}"; then
		shfmt_failed=1
	fi

	echo ""

	# Run shellcheck
	log_info "Running shellcheck..."
	if ! run_shellcheck "$mode" "${files[@]}"; then
		shellcheck_failed=1
	fi

	echo ""

	# Summary
	if [[ $shfmt_failed -eq 0 && $shellcheck_failed -eq 0 ]]; then
		log_success "All checks passed"
		return 0
	else
		log_warn "Some checks failed"
		if [[ $shfmt_failed -eq 1 ]]; then
			log_detail "shfmt: run with --format to fix"
		fi
		if [[ $shellcheck_failed -eq 1 ]]; then
			log_detail "shellcheck: fix issues manually"
		fi
		return 1
	fi
}
