#!/usr/bin/env bash
set -euo pipefail

# harvest-drivers.sh
# Harvest ChromeOS kernel modules, firmware, and modprobe configs from SHIM and optional RECOVERY.
# - Mounts partition 3 (ROOT-A) read-only from each image via losetup -P
# - Copies:
#   - SHIM p3: lib/modules, lib/firmware
#   - RECOVERY p3 (optional): merges lib/firmware, collects /lib/modprobe.d and /etc/modprobe.d into OUT/modprobe.d
# - Ensures cleanup of mounts and loop devices on exit.

ANSI_CLEAR='\033[0m'
ANSI_BOLD='\033[1m'
ANSI_GREEN='\033[1;32m'
ANSI_BLUE='\033[1;34m'
ANSI_YELLOW='\033[1;33m'
ANSI_RED='\033[1;31m'

log_step() {
  printf "${ANSI_BOLD}${ANSI_BLUE}[%s] %s${ANSI_CLEAR}\n" "$1" "$2"
}
log_info() {
  printf "${ANSI_GREEN}  → %s${ANSI_CLEAR}\n" "$1"
}
log_warn() {
  printf "${ANSI_YELLOW}  ! %s${ANSI_CLEAR}\n" "$1"
}
log_error() {
  printf "${ANSI_RED}  ✗ %s${ANSI_CLEAR}\n" "$1"
}

usage() {
  echo "Usage: $0 --shim PATH --out DIR [--recovery PATH]"
  exit 1
}

# --- Parse args ---
SHIM=""
RECOVERY=""
OUT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --shim)
      SHIM="${2:-}"; shift 2;;
    --recovery)
      RECOVERY="${2:-}"; shift 2;;
    --out)
      OUT="${2:-}"; shift 2;;
    -*)
      log_error "Unknown option: $1"; usage;;
    *)
      log_error "Unexpected argument: $1"; usage;;
  esac
done

[[ -z "${SHIM}" || -z "${OUT}" ]] && usage
if [[ ! -f "${SHIM}" ]]; then
  log_error "SHIM file not found: ${SHIM}"
  exit 2
fi
mkdir -p "${OUT}"

# --- Check dependencies ---
need_cmds=(losetup mount umount cp find xargs)
for c in "${need_cmds[@]}"; do
  if ! command -v "$c" >/dev/null 2>&1; then
    log_error "Missing dependency: $c"
    exit 3
  fi
done

# --- State & cleanup ---
WORKDIR="$(mktemp -d -p /tmp harvest-drivers.XXXXXX)"
SHIM_LOOP=""
RECOVERY_LOOP=""
MNT_SHIM="${WORKDIR}/mnt_shim"
MNT_RECOVERY="${WORKDIR}/mnt_recovery"
mkdir -p "${MNT_SHIM}" "${MNT_RECOVERY}"

cleanup() {
  set +e
  for mnt in "${MNT_RECOVERY}" "${MNT_SHIM}"; do
    if mountpoint -q "$mnt"; then sudo umount "$mnt"; fi
  done
  if [[ -n "${RECOVERY_LOOP}" ]] && losetup "${RECOVERY_LOOP}" >/dev/null 2>&1; then
    sudo losetup -d "${RECOVERY_LOOP}"
  fi
  if [[ -n "${SHIM_LOOP}" ]] && losetup "${SHIM_LOOP}" >/dev/null 2>&1; then
    sudo losetup -d "${SHIM_LOOP}"
  fi
  rm -rf "${WORKDIR}"
  set -e
}
trap cleanup EXIT

# --- Mount SHIM p3 and copy modules/firmware ---
log_step "Harvest" "Mount SHIM p3 read-only and copy drivers"
SHIM_LOOP="$(sudo losetup --show -fP "${SHIM}")"
if [[ ! -b "${SHIM_LOOP}p3" ]]; then
  log_error "SHIM rootfs partition not found at ${SHIM_LOOP}p3"
  exit 4
fi
sudo mount -o ro "${SHIM_LOOP}p3" "${MNT_SHIM}"

# Copy lib/modules and lib/firmware preserving attributes
mkdir -p "${OUT}/lib"
if [[ -d "${MNT_SHIM}/lib/modules" ]]; then
  log_info "Copying SHIM lib/modules → ${OUT}/lib/modules"
  sudo cp -ar "${MNT_SHIM}/lib/modules" "${OUT}/lib/modules"
else
  log_warn "SHIM has no lib/modules directory"
fi
if [[ -d "${MNT_SHIM}/lib/firmware" ]]; then
  log_info "Copying SHIM lib/firmware → ${OUT}/lib/firmware"
  sudo cp -ar "${MNT_SHIM}/lib/firmware" "${OUT}/lib/firmware"
else
  log_warn "SHIM has no lib/firmware directory"
  mkdir -p "${OUT}/lib/firmware"
fi

# --- Optional: mount RECOVERY p3 and merge firmware + collect modprobe.d ---
if [[ -n "${RECOVERY:-}" ]]; then
  if [[ ! -f "${RECOVERY}" ]]; then
    log_error "RECOVERY file not found: ${RECOVERY}"
    exit 5
  fi
  log_step "Harvest" "Mount RECOVERY p3 read-only and merge firmware and modprobe.d"
  RECOVERY_LOOP="$(sudo losetup --show -fP "${RECOVERY}")"
  if [[ ! -b "${RECOVERY_LOOP}p3" ]]; then
    log_error "RECOVERY rootfs partition not found at ${RECOVERY_LOOP}p3"
    exit 6
  fi
  sudo mount -o ro "${RECOVERY_LOOP}p3" "${MNT_RECOVERY}"

  # Merge firmware
  mkdir -p "${OUT}/lib/firmware"
  if [[ -d "${MNT_RECOVERY}/lib/firmware" ]]; then
    log_info "Merging RECOVERY firmware → ${OUT}/lib/firmware"
    sudo cp -ar "${MNT_RECOVERY}/lib/firmware/." "${OUT}/lib/firmware/" 2>/dev/null || true
  else
    log_warn "RECOVERY has no lib/firmware directory"
  fi

  # Collect modprobe.d from both lib and etc
  mkdir -p "${OUT}/modprobe.d"
  if [[ -d "${MNT_RECOVERY}/lib/modprobe.d" ]]; then
    log_info "Copying RECOVERY lib/modprobe.d → ${OUT}/modprobe.d"
    sudo cp -ar "${MNT_RECOVERY}/lib/modprobe.d/." "${OUT}/modprobe.d/" 2>/dev/null || true
  fi
  if [[ -d "${MNT_RECOVERY}/etc/modprobe.d" ]]; then
    log_info "Copying RECOVERY etc/modprobe.d → ${OUT}/modprobe.d"
    sudo cp -ar "${MNT_RECOVERY}/etc/modprobe.d/." "${OUT}/modprobe.d/" 2>/dev/null || true
  fi
fi

log_info "Harvest complete. Output at: ${OUT}"