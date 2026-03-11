#!/usr/bin/env bash

# push-to-cachix.sh
#
# Purpose: Push Nix derivations to Cachix binary cache
#
# This module:
# - Pushes NixOS system derivations to personal Cachix cache
# - Supports selective host/profile pushing
# - Provides dry-run mode for testing

set -Eeuo pipefail

# === Logging (self-contained for portability) ===
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
	ANSI_CLEAR='\033[0m'
	ANSI_BOLD='\033[1m'
	ANSI_GREEN='\033[1;32m'
	ANSI_YELLOW='\033[1;33m'
	ANSI_RED='\033[1;31m'
else
	ANSI_CLEAR=''
	ANSI_BOLD=''
	ANSI_GREEN=''
	ANSI_YELLOW=''
	ANSI_RED=''
fi

log_info() { printf "${ANSI_GREEN}  → %s${ANSI_CLEAR}\n" "$1"; }
log_warn() { printf "${ANSI_YELLOW}  ! %s${ANSI_CLEAR}\n" "$1"; }
log_error() { printf "${ANSI_RED}  ✗ %s${ANSI_CLEAR}\n" "$1"; }
log_success() { printf "${ANSI_GREEN}  ✓ %s${ANSI_CLEAR}\n" "$1"; }

# === Configuration ===
CACHE="popcat19-shared"
HOSTS=()
PROFILES=()
SKIP_HOSTS=()
DRY_RUN=0

# === Usage ===
usage() {
	cat <<'EOF'
Usage: push-to-cachix.sh [OPTIONS]

Options:
    --host HOST              Host to push (can be specified multiple times)
    --profile PROFILE       Profile to push (can be specified multiple times)
    --all-hosts             Push all hosts
    --skip-host HOST        Skip specific host (can be specified multiple times)
    --dry-run               Show what would be done
    --help                 Show this help

Examples:
    # Push single host
    ./push-to-cachix.sh --host popcat19-nixos0

    # Push multiple hosts
    ./push-to-cachix.sh --host popcat19-nixos0 --host popcat19-thinkpad0

    # Push all hosts except one
    ./push-to-cachix.sh --all-hosts --skip-host popcat19-surface0
EOF
}

# === Parse arguments ===
while [[ $# -gt 0 ]]; do
	case "$1" in
	--host)
		HOSTS+=("${2:-}")
		shift 2
		;;
	--profile)
		PROFILES+=("${2:-}")
		shift 2
		;;
	--all-hosts)
		ALL_HOSTS=1
		shift
		;;
	--skip-host)
		SKIP_HOSTS+=("${2:-}")
		shift 2
		;;
	--dry-run)
		DRY_RUN=1
		shift
		;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		log_error "Unknown option: $1"
		usage
		exit 1
		;;
	esac
done

# === Helpers ===
is_skipped() {
	local host="$1"
	for skip in "${SKIP_HOSTS[@]}"; do
		if [[ "$host" == "$skip" ]]; then
			return 0
		fi
	done
	return 1
}

should_push_host() {
	local host="$1"

	if [[ "${#HOSTS[@]}" -gt 0 ]]; then
		for h in "${HOSTS[@]}"; do
			[[ "$host" == "$h" ]] && return 0
		done
		return 1
	fi

	[[ "${ALL_HOSTS:-0}" -eq 1 ]] && return 0
	return 1
}

# === Check dependencies ===
check_deps() {
	local missing=()
	for cmd in cachix nix; do
		if ! command -v "$cmd" >/dev/null 2>&1; then
			missing+=("$cmd")
		fi
	done
	if [[ ${#missing[@]} -gt 0 ]]; then
		log_error "Missing dependencies: ${missing[*]}"
		return 1
	fi
}

# === Push host system ===
push_host() {
	local host="$1"

	log_info "Pushing system for host: $host"

	# Get the system derivation
	local drv=".#nixosConfigurations.${host}.config.system.build.toplevel"

	if [[ "$DRY_RUN" -eq 1 ]]; then
		log_info "[DRY-RUN] Would push: $drv"
		return 0
	fi

	# Get store path
	local store_path
	store_path=$(nix path-info --impure --accept-flake-config "$drv" 2>/dev/null || echo "")

	if [[ -z "$store_path" ]]; then
		log_warn "Could not resolve $drv for host $host"
		return 1
	fi

	log_info "Pushing to $CACHE: $(basename "$store_path")"

	# Push to cachix
	if cachix push "$CACHE" "$store_path" 2>&1 | grep -v -E "(Compressing|All done)" | grep -q .; then
		log_success "Pushed $host"
	else
		log_error "Failed to push $host"
		return 1
	fi
}

# === Push profiles ===
push_profiles() {
	for profile in "${PROFILES[@]}"; do
		log_info "Pushing profile: $profile"

		local drv=".#profiles.${profile}"
		local store_path
		store_path=$(nix path-info --impure --accept-flake-config "$drv" 2>/dev/null || echo "")

		if [[ -z "$store_path" ]]; then
			log_warn "Could not resolve $drv"
			continue
		fi

		if [[ "$DRY_RUN" -eq 1 ]]; then
			log_info "[DRY-RUN] Would push: $store_path"
			continue
		fi

		log_info "Pushing to $CACHE: $(basename "$store_path")"

		if cachix push "$CACHE" "$store_path" 2>&1 | grep -v -E "(Compressing|All done)" | grep -q .; then
			log_success "Pushed profile: $profile"
		else
			log_error "Failed to push profile: $profile"
		fi
	done
}

# === Main ===
main() {
	log_info "Cachix Push Tool"
	log_info "Cache: $CACHE"

	if [[ "$DRY_RUN" -eq 1 ]]; then
		log_warn "DRY-RUN mode enabled"
	fi

	check_deps || exit 1

	# Discover available hosts if needed
	if [[ "${#HOSTS[@]}" -eq 0 && "${ALL_HOSTS:-0}" -eq 0 ]]; then
		log_info "No hosts specified, discovering from flake..."

		# Try to get hosts from flake
		local hosts_json
		hosts_json=$(nix eval --raw --impure --accept-flake-config '.#hosts' 2>/dev/null || echo "")

		if [[ -n "$hosts_json" ]]; then
			# Parse hosts from JSON (simple approach)
			while read -r host; do
				if [[ -n "$host" && ! "$host" =~ ^[[:space:]]*$ ]]; then
					HOSTS+=("$host")
				fi
			done <<<"$hosts_json"
		fi

		if [[ ${#HOSTS[@]} -eq 0 ]]; then
			log_error "No hosts found. Specify --host or --all-hosts"
			exit 1
		fi
	fi

	# Push hosts
	local failed=0
	for host in "${HOSTS[@]}"; do
		if is_skipped "$host"; then
			log_info "Skipping host: $host"
			continue
		fi

		if ! should_push_host "$host"; then
			continue
		fi

		if ! push_host "$host"; then
			((failed++))
		fi
	done

	# Push profiles
	if [[ ${#PROFILES[@]} -gt 0 ]]; then
		push_profiles
	fi

	if [[ $failed -gt 0 ]]; then
		log_error "$failed host(s) failed to push"
		exit 1
	fi

	log_success "Cachix push complete"
}

main "$@"
