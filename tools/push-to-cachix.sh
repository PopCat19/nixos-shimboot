#!/usr/bin/env bash

# Push to Cachix Script
#
# Purpose: Push Nix derivations to Cachix (image upload no longer supported)
# Dependencies: cachix, nix
# Related: assemble-final.sh, check-cachix.sh
#
# This script handles Cachix push operations:
# - Pushes Nix derivations (kernel, initramfs, rootfs)
# - Note: Image upload disabled due to cachix removing --file option
#
# Usage:
#   ./tools/push-to-cachix.sh --board BOARD [OPTIONS]
#
# Options:
#   --board BOARD              Target board (required)
#   --rootfs FLAVOR            Rootfs variant (full, minimal)
#   --drivers MODE             Driver mode (vendor, inject, both, none)
#   --image PATH               Path to final shimboot.img (for info only, not uploaded)
#   --skip-derivations         Skip pushing Nix derivations
#   --skip-image               Skip image info display
#   --dry-run                  Show what would be done
#
# Examples:
#   # Push derivations only
#   ./tools/push-to-cachix.sh --board dedede
#
#   # Show image info (no upload)
#   ./tools/push-to-cachix.sh --board dedede --image work/shimboot.img --rootfs full --drivers vendor
#
#   # Dry run
#   ./tools/push-to-cachix.sh --board dedede --image work/shimboot.img --dry-run

set -euo pipefail

# Colors
readonly BLUE='\033[0;34m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly NC='\033[0m'

log_info() { printf "${BLUE}[INFO]${NC} %s\n" "$*" >&2; }
log_success() { printf "${GREEN}[SUCCESS]${NC} %s\n" "$*" >&2; }
log_warn() { printf "${YELLOW}[WARN]${NC} %s\n" "$*" >&2; }
log_error() { printf "${RED}[ERROR]${NC} %s\n" "$*" >&2; }

# Configuration
CACHE="shimboot-systemd-nixos"
BOARD=""
ROOTFS_FLAVOR="full"
DRIVERS_MODE="vendor"
IMAGE_PATH=""
SKIP_DERIVATIONS=0
SKIP_IMAGE=0
DRY_RUN=0

usage() {
    cat << 'EOF'
Usage: push-to-cachix.sh --board BOARD [OPTIONS]

Options:
    --board BOARD              Target board (required)
    --rootfs FLAVOR            Rootfs variant (full, minimal)
    --drivers MODE             Driver mode (vendor, inject, both, none)
    --image PATH               Path to final shimboot.img (for info only, not uploaded)
    --skip-derivations         Skip pushing Nix derivations
    --skip-image               Skip image info display
    --dry-run                  Show what would be done

Examples:
    # Push derivations only
    ./push-to-cachix.sh --board dedede

    # Show image info (no upload)
    ./push-to-cachix.sh --board dedede --image work/shimboot.img --rootfs full --drivers vendor
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --board)
            BOARD="${2:-}"
            shift 2
            ;;
        --rootfs)
            ROOTFS_FLAVOR="${2:-full}"
            shift 2
            ;;
        --drivers)
            DRIVERS_MODE="${2:-vendor}"
            shift 2
            ;;
        --image)
            IMAGE_PATH="${2:-}"
            shift 2
            ;;
        --skip-derivations)
            SKIP_DERIVATIONS=1
            shift
            ;;
        --skip-image)
            SKIP_IMAGE=1
            shift
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        -h|--help)
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

# Validate arguments
if [[ -z "$BOARD" ]]; then
    log_error "Board is required (--board BOARD)"
    usage
    exit 1
fi

# Check dependencies
for cmd in cachix nix curl zstd; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        log_error "Missing dependency: $cmd"
        exit 1
    fi
done

# CI detection
is_ci() {
    [[ "${CI:-}" == "true" ]] || \
    [[ -n "${GITHUB_ACTIONS:-}" ]] || \
    [[ -n "${GITLAB_CI:-}" ]] || \
    [[ -n "${JENKINS_HOME:-}" ]]
}

# Safe execution wrapper
safe_exec() {
    if [[ "$DRY_RUN" -eq 1 ]]; then
        log_info "[DRY-RUN] Would execute: $*"
    else
        "$@"
    fi
}

# Compute configuration hash
compute_config_hash() {
    local board="$1"
    local rootfs="$2"
    local drivers="$3"
    local git_commit="${4:-unknown}"
    
    echo "${board}-${rootfs}-${drivers}-${git_commit}" | sha256sum | cut -d' ' -f1 | cut -c1-16
}

# Push Nix derivations
push_derivations() {
    local board="$1"
    local rootfs_attr="raw-rootfs"
    
    if [[ "$ROOTFS_FLAVOR" == "minimal" ]]; then
        rootfs_attr="raw-rootfs-minimal"
    fi
    
    log_info "Pushing Nix derivations for board: $board"
    
    local derivations=(
        ".#chromeos-shim-${board}"
        ".#extracted-kernel-${board}"
        ".#initramfs-patching-${board}"
        ".#${rootfs_attr}"
    )
    
    for drv in "${derivations[@]}"; do
        log_info "Pushing $drv..."
        
        if [[ "$DRY_RUN" -eq 1 ]]; then
            # For dry-run, just check if derivation exists without building
            if ! nix eval --raw "$drv" >/dev/null 2>&1; then
                log_warn "Failed to evaluate $drv, skipping push"
                continue
            fi
            
            # Get store path for dry-run display
            local store_path
            store_path=$(nix path-info "$drv" 2>/dev/null || echo "")
            
            if [[ -n "$store_path" ]] && [[ "$store_path" =~ (chromeos-shim|extracted-kernel|initramfs|raw-rootfs) ]]; then
                log_info "[DRY-RUN] Would push: $store_path"
            else
                log_info "[DRY-RUN] Skipping nixpkgs derivation"
            fi
        else
            # Actually build for real runs
            if ! nix build --quiet "$drv" 2>/dev/null; then
                log_warn "Failed to build $drv, skipping push"
                continue
            fi
            
            local store_path
            store_path=$(nix path-info "$drv" 2>/dev/null || echo "")
            
            if [[ -z "$store_path" ]]; then
                log_warn "Could not get store path for $drv"
                continue
            fi
            
            # Only push our derivations, not nixpkgs dependencies
            if [[ "$store_path" =~ (chromeos-shim|extracted-kernel|initramfs|raw-rootfs) ]]; then
                safe_exec cachix push "$CACHE" "$store_path" 2>&1 | grep -v "Compressing" || true
            else
                log_info "Skipping nixpkgs derivation: $(basename "$store_path")"
            fi
        fi
    done
}

# Upload final image (disabled - cachix no longer supports arbitrary file uploads)
upload_image() {
    local image_path="$1"
    local board="$2"
    local rootfs="$3"
    local drivers="$4"
    
    if [[ ! -f "$image_path" ]]; then
        log_error "Image not found: $image_path"
        return 1
    fi
    
    log_warn "Image upload to Cachix is no longer supported"
    log_warn "Cachix removed --file option in newer versions"
    log_warn "Image remains at: $image_path"
    
    # Get git commit
    local git_commit="unknown"
    if command -v git >/dev/null 2>&1 && [[ -d .git ]]; then
        git_commit=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    fi
    
    # Compute config hash for reference
    local config_hash
    config_hash=$(compute_config_hash "$board" "$rootfs" "$drivers" "$git_commit")
    
    log_info "Image info for reference:"
    log_info "  Board: $board"
    log_info "  Rootfs: $rootfs"
    log_info "  Drivers: $drivers"
    log_info "  Config hash: $config_hash"
    log_info "  Size: $(du -h "$image_path" | cut -f1)"
}

# Main execution
main() {
    log_info "Cachix Push Tool"
    log_info "Cache: $CACHE"
    log_info "Board: $BOARD"
    log_info "Rootfs: $ROOTFS_FLAVOR"
    log_info "Drivers: $DRIVERS_MODE"
    
    if is_ci; then
        log_info "CI environment detected"
    fi
    
    # Push derivations
    if [[ "$SKIP_DERIVATIONS" -eq 0 ]]; then
        push_derivations "$BOARD"
    else
        log_info "Skipping derivation push (--skip-derivations)"
    fi
    
    # Upload image
    if [[ -n "$IMAGE_PATH" ]] && [[ "$SKIP_IMAGE" -eq 0 ]]; then
        upload_image "$IMAGE_PATH" "$BOARD" "$ROOTFS_FLAVOR" "$DRIVERS_MODE"
    elif [[ "$SKIP_IMAGE" -eq 1 ]]; then
        log_info "Skipping image upload (--skip-image)"
    elif [[ -z "$IMAGE_PATH" ]]; then
        log_info "No image path provided (--image PATH)"
    fi
    
    log_success "Cachix push complete"
}

main "$@"