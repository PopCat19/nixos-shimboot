#!/usr/bin/env bash
# shellcheck disable=SC2317,SC2162
#
# Stage 2 Activation Inspection Utility
#
# Purpose: Inspect and optionally patch the NixOS stage‑2 activation script
# at the latest generation. Supports custom pattern search and interactive editing.
#
# Dependencies: mount, umount, grep, awk, sed, nano/vim
# Related: assemble-final.sh
#

set -euo pipefail

# === Colors & Logging ===
ANSI_CLEAR='\033[0m'
ANSI_BOLD='\033[1m'
ANSI_GREEN='\033[1;32m'
ANSI_BLUE='\033[1;34m'
ANSI_YELLOW='\033[1;33m'
ANSI_RED='\033[1;31m'
ANSI_CYAN='\033[1;36m'

log_step() { printf "${ANSI_BOLD}${ANSI_BLUE}[%s] %s${ANSI_CLEAR}\n" "$1" "$2"; }
log_info() { printf "${ANSI_GREEN}  → %s${ANSI_CLEAR}\n" "$1"; }
log_warn() { printf "${ANSI_YELLOW}  ! %s${ANSI_CLEAR}\n" "$1"; }
log_error() { printf "${ANSI_RED}  ✗ %s${ANSI_CLEAR}\n" "$1"; }
log_success() { printf "${ANSI_GREEN}  ✓ %s${ANSI_CLEAR}\n" "$1"; }

# === Configuration ===
TARGET_PARTITION="${1:-}"
MOUNTPOINT="/mnt/nixos-rollback"
EDITOR="${EDITOR:-nano}"

# --- Functions ---

detect_partition() {
  log_info "Auto-detecting NixOS partitions..."
  for part in /dev/sd[a-z]{4,6} /dev/nvme[0-9]n1p{4,6}; do
    [[ -b "$part" ]] || continue
    if mkdir -p "$MOUNTPOINT" && mount "$part" "$MOUNTPOINT" 2>/dev/null; then
      if [[ -d "$MOUNTPOINT/nix" && -d "$MOUNTPOINT/etc/nixos" ]]; then
        TARGET_PARTITION="$part"
        umount "$MOUNTPOINT" 2>/dev/null
        break
      fi
      umount "$MOUNTPOINT" 2>/dev/null || true
    fi
  done
  if [[ -z "${TARGET_PARTITION:-}" ]]; then
    log_error "Could not auto-detect NixOS partition"
    log_info "Available partitions:"
    lsblk -o NAME,SIZE,MOUNTPOINT | grep -E "part|disk" || true
    exit 1
  fi
}

ensure_root() {
  if [[ "$EUID" -ne 0 ]]; then
    log_error "This script must be run as root"
    log_info "Usage: sudo $0 [partition]"
    exit 1
  fi
}

cleanup() {
  log_info "Cleaning up..."
  set +e
  umount "$MOUNTPOINT" 2>/dev/null || true
  set -e
}
trap cleanup EXIT

# --- Begin operation ---
ensure_root
[[ -n "$TARGET_PARTITION" ]] || detect_partition

# Validate partition
if [[ ! -b "$TARGET_PARTITION" ]]; then
  log_error "Partition does not exist: $TARGET_PARTITION"
  lsblk
  exit 1
fi

mkdir -p "$MOUNTPOINT"

log_step "1/3" "Mounting partition"
if ! mount "$TARGET_PARTITION" "$MOUNTPOINT"; then
  log_error "Failed to mount $TARGET_PARTITION"
  exit 1
fi
log_info "Mounted root partition: $TARGET_PARTITION"

# === Step 2: Find latest generation ===
log_step "2/3" "Locating latest system generation"
PROFILE_DIR="$MOUNTPOINT/nix/var/nix/profiles"

if [[ ! -d "$PROFILE_DIR" ]]; then
  log_error "Invalid NixOS profile directory"
  exit 1
fi

mapfile -t GENERATIONS < <(find "$PROFILE_DIR" -maxdepth 1 -type l -name "system-*-link" | sort -V)
LATEST_GEN="${GENERATIONS[-1]:-}"

if [[ -z "$LATEST_GEN" ]]; then
  log_error "Could not find any generations"
  exit 1
fi

LATEST_TARGET=$(readlink -f "$LATEST_GEN")
log_info "Latest generation: $(basename "$LATEST_GEN")"
log_info "Resolved store path: $LATEST_TARGET"

# === Step 3: Activation script inspection ===
ACTIVATE_PATH="$MOUNTPOINT$LATEST_TARGET/activate"

if [[ ! -f "$ACTIVATE_PATH" ]]; then
  log_error "Activation script not found: $ACTIVATE_PATH"
  exit 1
fi

log_step "3/3" "Inspect/patch activation script"

PS3="Select action: "
select opt in \
  "List first 40 lines" \
  "Search (custom grep pattern)" \
  "Search known hotfix keywords" \
  "Edit activation script" \
  "Exit"; do
  case "$opt" in
  "List first 40 lines")
    log_info "Preview of activation script:"
    head -n 40 "$ACTIVATE_PATH"
    ;;
  "Search (custom grep pattern)")
    read -rp "Enter custom grep pattern: " PATTERN
    [[ -n "$PATTERN" ]] || { log_warn "Empty pattern"; continue; }
    grep -n -H "$PATTERN" "$ACTIVATE_PATH" || log_warn "No matches found"
    ;;
  "Search known hotfix keywords")
    log_info "Scanning activation script for suspicious or fixable patterns..."
    grep -nE 'fix-|bwrap|mount|shm|sandbox|steam|chmod|cp|wrapper|safety' \
      "$ACTIVATE_PATH" || log_warn "No known keywords found."
    ;;
  "Edit activation script")
    log_info "Opening editor: $EDITOR"
    "$EDITOR" "$ACTIVATE_PATH"
    log_success "Edited activation script."
    ;;
  "Exit")
    log_info "Goodbye."
    break
    ;;
  *)
    log_warn "Invalid choice, try again."
    ;;
  esac
done