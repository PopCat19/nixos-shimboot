# nix.sh
#
# Purpose: Provide Nix and Cachix interaction helpers
#
# This module:
# - Checks Nix availability
# - Resolves flake attrs to store paths
# - Probes Cachix for cached artifacts
# - Provides common Nix build flags

# shellcheck shell=bash

require_nix() {
	if ! command -v nix >/dev/null 2>&1; then
		log_error "Nix is required but not installed"
		return 1
	fi
}

flake_attr_exists() {
	local flake="$1"
	local attr="$2"
	nix build --no-link --print-out-paths "${flake}#${attr}" >/dev/null 2>&1
}

store_path_for_attr() {
	local flake="$1"
	local attr="$2"
	nix build --no-link --print-out-paths "${flake}#${attr}" 2>/dev/null
}

cachix_has_store_path() {
	local cache="$1"
	local store_path="$2"

	if [[ -z "${CACHIX_AUTH_TOKEN:-}" ]]; then
		return 1
	fi

	cachix ls "$cache" 2>/dev/null | grep -q "$store_path"
}

cachix_push() {
	local cache="$1"
	local store_path="$2"

	if [[ -z "${CACHIX_AUTH_TOKEN:-}" ]]; then
		log_warn "CACHIX_AUTH_TOKEN not set, skipping push"
		return 1
	fi

	cachix push "$cache" "$store_path"
}

nix_build_to_store() {
	local flake_ref="$1"
	local attr="$2"

	nix build --print-out-paths "${flake_ref}#${attr}"
}

nix_shell_eval() {
	local flake="$1"
	local expr="$2"

	nix eval --raw "${flake}#${expr}"
}
