# check-context.sh
#
# Purpose: Verifies context.md files match actual directory contents
#
# This module:
# - Detects drift between context.md entries and filesystem
# - Can run as pre-commit hook or standalone check
#
# shellcheck shell=bash

# Ensure script is sourced, not executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	echo "Error: check-context.sh should be sourced, not executed" >&2
	exit 1
fi

# Check context.md files for drift
check_context_drift() {
	local root="${1:-.}"
	local error=0
	local found_context=0

	while IFS= read -r context_file; do
		found_context=1
		local dir
		dir=$(dirname "$context_file")

		# Structural check: listed files vs actual files
		local listed
		listed=$(grep -oE '`[^`]+`' "$context_file" 2>/dev/null | tr -d '`' | sort)

		local actual
		actual=$(find "$dir" -maxdepth 1 -type f ! -name 'context.md' \
			-exec basename {} \; 2>/dev/null | sort)

		if [[ "$listed" != "$actual" ]]; then
			log_warn "context.md structural drift: $context_file"
			diff <(echo "$listed") <(echo "$actual") 2>/dev/null | grep '^[<>]' |
				sed 's/^< /  listed but missing: /; s/^> /  exists but unlisted: /'
			error=1
		fi

		# Content check: context.md entries match file header Purpose lines
		while IFS= read -r line; do
			local filename
			local ctx_desc
			filename=$(echo "$line" | grep -oE '`[^`]+`' | tr -d '`')
			ctx_desc=$(echo "$line" | sed -n 's/.*— //p')

			[[ -z "$filename" || -z "$ctx_desc" ]] && continue

			local filepath="$dir/$filename"
			[[ ! -f "$filepath" ]] && continue

			# Extract Purpose line from file header
			local header_desc
			header_desc=$(grep -m1 '^# Purpose:' "$filepath" 2>/dev/null | sed 's/^# Purpose: //')

			if [[ -n "$header_desc" && "$ctx_desc" != "$header_desc" ]]; then
				log_warn "context.md content drift: $context_file"
				log_detail "  $filename"
				log_detail "    context.md : $ctx_desc"
				log_detail "    header     : $header_desc"
				error=1
			elif [[ -z "$header_desc" ]]; then
				log_warn "context.md entry references file without header: $filename"
				log_detail "  File in $context_file lacks required header with Purpose:"
				error=1
			fi
		done < <(grep -P '^\- `' "$context_file" 2>/dev/null)

		if [[ $error -eq 0 ]]; then
			log_detail "OK: $context_file"
		fi
	done < <(find "$root" -name 'context.md' -not -path '*/.git/*' 2>/dev/null)

	if [[ $found_context -eq 0 ]]; then
		log_detail "No context.md files found"
	fi

	if [[ $error -eq 1 ]]; then
		return 1
	fi
	return 0
}

# Install as pre-commit hook
install_context_hook() {
	local hook_dir="${PROJECT_ROOT}/.git/hooks"
	local hook_file="$hook_dir/pre-commit"

	if [[ ! -d "$hook_dir" ]]; then
		log_error "Not a git repository or .git/hooks not found"
		return 1
	fi

	local hook_content='
# dev-conventions context.md drift check
if [[ -f ".dev-conventions/context.sh" ]]; then
    source .dev-conventions/context.sh 2>/dev/null || true
    if declare -f check_context_drift &>/dev/null; then
        if ! check_context_drift .; then
            echo "context.md drift detected. Fix before committing." >&2
            exit 1
        fi
    fi
elif [[ -f "conventions/src/check-context.sh" ]]; then
    source conventions/src/check-context.sh
    if ! check_context_drift .; then
        echo "context.md drift detected. Fix before committing." >&2
        exit 1
    fi
fi
'

	if [[ -f "$hook_file" ]]; then
		if grep -q "context.md drift check" "$hook_file" 2>/dev/null; then
			log_info "Context hook already installed"
			return 0
		fi
		log_warn "Existing pre-commit hook found. Appending context check."
		echo "$hook_content" >>"$hook_file"
	else
		cat >"$hook_file" <<'EOF'
#!/usr/bin/env bash
EOF
		echo "$hook_content" >>"$hook_file"
		chmod +x "$hook_file"
	fi

	log_info "Installed context.md pre-commit hook: $hook_file"
}

# Remove context hook
remove_context_hook() {
	local hook_file="${PROJECT_ROOT}/.git/hooks/pre-commit"

	if [[ ! -f "$hook_file" ]]; then
		log_info "No pre-commit hook found"
		return 0
	fi

	if grep -q "context.md drift check" "$hook_file" 2>/dev/null; then
		local temp_file
		temp_file=$(mktemp)
		sed '/# dev-conventions context.md drift check/,/^fi$/d' "$hook_file" >"$temp_file"

		if [[ $(wc -l <"$temp_file") -le 2 ]]; then
			rm -f "$hook_file"
			log_info "Removed pre-commit hook (was only dev-conventions)"
		else
			mv "$temp_file" "$hook_file"
			log_info "Removed context.md check from pre-commit hook"
		fi
		rm -f "$temp_file"
	else
		log_info "Pre-commit hook exists but not managed by dev-conventions"
	fi
}

# Main command
cmd_check_context() {
	local install_hook=false
	local remove_hook=false
	local root="."

	while [[ $# -gt 0 ]]; do
		case "$1" in
		--install-hook)
			install_hook=true
			shift
			;;
		--remove-hook)
			remove_hook=true
			shift
			;;
		--root)
			root="$2"
			shift 2
			;;
		*)
			log_error "Unknown option: $1"
			return 1
			;;
		esac
	done

	if [[ "$install_hook" == "true" ]]; then
		install_context_hook
		return $?
	fi

	if [[ "$remove_hook" == "true" ]]; then
		remove_context_hook
		return $?
	fi

	log_info "Checking context.md files in $root..."
	echo ""
	check_context_drift "$root"
}
