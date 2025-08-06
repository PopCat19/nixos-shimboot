#!/usr/bin/env bash

# Initramfs Patching Script for Shimboot
# This script patches the extracted initramfs with shimboot bootloader files

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INITRAMFS_DIR="${SCRIPT_DIR}/initramfs-extracted"
BOOTLOADER_DIR="${SCRIPT_DIR}/../bootloader"
LOG_FILE="${SCRIPT_DIR}/patch-initramfs.log"

# Logging functions
log_info() {
    echo "[INFO] $1" | tee -a "$LOG_FILE"
}

log_warn() {
    echo "[WARN] $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo "[ERROR] $1" | tee -a "$LOG_FILE" >&2
}

log_debug() {
    if [[ "${DEBUG:-0}" == "1" ]]; then
        echo "[DEBUG] $1" | tee -a "$LOG_FILE"
    fi
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if initramfs directory exists
    if [ ! -d "$INITRAMFS_DIR" ]; then
        log_error "Initramfs directory not found: $INITRAMFS_DIR"
        log_error "Please run extract-initramfs.sh first"
        exit 1
    fi
    
    # Check if bootloader directory exists
    if [ ! -d "$BOOTLOADER_DIR" ]; then
        log_error "Bootloader directory not found: $BOOTLOADER_DIR"
        exit 1
    fi
    
    # Check if init script exists
    if [ ! -f "$INITRAMFS_DIR/init" ]; then
        log_error "Init script not found: $INITRAMFS_DIR/init"
        exit 1
    fi
    
    # Check if required bootloader files exist
    local required_files=("bin/bootstrap.sh" "bin/init" "opt/crossystem" "opt/mount-encrypted")
    for file in "${required_files[@]}"; do
        if [ ! -f "$BOOTLOADER_DIR/$file" ]; then
            log_error "Required bootloader file not found: $BOOTLOADER_DIR/$file"
            exit 1
        fi
    done
    
    log_info "Prerequisites check passed"
}

# Backup original init script
backup_init_script() {
    log_info "Backing up original init script..."
    cp "$INITRAMFS_DIR/init" "$INITRAMFS_DIR/init.backup"
    log_info "Original init script backed up to: $INITRAMFS_DIR/init.backup"
}

# Copy bootloader files to initramfs
copy_bootloader_files() {
    log_info "Copying bootloader files to initramfs..."
    
    # Copy entire bootloader directory structure
    if ! cp -rT "$BOOTLOADER_DIR" "$INITRAMFS_DIR/"; then
        log_error "Failed to copy bootloader files"
        exit 1
    fi
    
    log_info "Bootloader files copied successfully"
}

# Patch init script to execute shimboot bootloader
patch_init_script() {
    log_info "Patching init script to execute shimboot bootloader..."
    
    local init_script="$INITRAMFS_DIR/init"
    
    # Create a backup if it doesn't exist
    if [ ! -f "$init_script.backup" ]; then
        backup_init_script
    fi
    
    # Read the original init script
    local original_content
    original_content=$(cat "$init_script")
    
    # Create new init script content
    cat > "$init_script" << 'EOF'
#!/bin/busybox sh
# Copyright 2015 The Chromium OS Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#
# /init script for use in factory install shim.
# Note that this script uses the busybox shell (not bash, not dash).
set -x

. /lib/init.sh

setup_environment() {
  initialize

  # Install additional utility programs.
  /bin/busybox --install /bin || true
}

main() {
  setup_environment
  # In case an error is not handled by bootstrapping, stop here
  # so that an operator can see installation stop.
  exec /bin/bootstrap.sh || sleep 1d
}

# Make this source-able for testing.
if [ "$0" = "/init" ]; then
  main "$@"
  # Should never reach here.
  exit 1
fi
EOF
    
    log_info "Init script patched successfully"
}

# Make bootloader scripts executable
make_scripts_executable() {
    log_info "Making bootloader scripts executable..."
    
    # Make all files in bin/ executable
    find "$INITRAMFS_DIR/bin" -type f -exec chmod +x {} \;
    
    # Make sure specific files are executable
    chmod +x "$INITRAMFS_DIR/bin/bootstrap.sh"
    chmod +x "$INITRAMFS_DIR/bin/init"
    
    log_info "Bootloader scripts made executable"
}

# Verify patching
verify_patching() {
    log_info "Verifying initramfs patching..."
    
    local verification_passed=true
    
    # Check if bootloader files exist
    local required_files=("bin/bootstrap.sh" "bin/init" "opt/crossystem" "opt/mount-encrypted")
    for file in "${required_files[@]}"; do
        if [ ! -f "$INITRAMFS_DIR/$file" ]; then
            log_error "Missing bootloader file: $file"
            verification_passed=false
        fi
    done
    
    # Check if init script contains bootstrap.sh
    if ! grep -q "bootstrap.sh" "$INITRAMFS_DIR/init"; then
        log_error "Init script does not contain bootstrap.sh execution"
        verification_passed=false
    fi
    
    # Check if files are executable
    if [ ! -x "$INITRAMFS_DIR/bin/bootstrap.sh" ]; then
        log_error "bootstrap.sh is not executable"
        verification_passed=false
    fi
    
    if [ ! -x "$INITRAMFS_DIR/bin/init" ]; then
        log_error "init is not executable"
        verification_passed=false
    fi
    
    if [ "$verification_passed" = true ]; then
        log_info "Initramfs patching verification passed"
    else
        log_error "Initramfs patching verification failed"
        exit 1
    fi
}

# Main function
main() {
    log_info "Starting initramfs patching process..."
    
    # Clear log file
    > "$LOG_FILE"
    
    # Check prerequisites
    check_prerequisites
    
    # Backup original init script
    backup_init_script
    
    # Copy bootloader files
    copy_bootloader_files
    
    # Patch init script
    patch_init_script
    
    # Make scripts executable
    make_scripts_executable
    
    # Verify patching
    verify_patching
    
    log_info "Initramfs patching completed successfully!"
    log_info "Patched initramfs available at: $INITRAMFS_DIR"
}

# Run main function
main "$@"