#!/usr/bin/env bash

# Initramfs extraction script for ChromeOS kernel
# Adapted from archive/scripts-old/lib/harvest.sh

set -e

# Configuration
KERNEL_FILE="./extracted-kernel"
WORK_DIR="./temp"
INITRAMFS_DIR="./initramfs-extracted"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if kernel file exists
    if [ ! -f "$KERNEL_FILE" ]; then
        log_error "Kernel file not found at $KERNEL_FILE"
        log_info "Please run extract-kernel.sh first"
        exit 1
    fi
    
    # Check required commands
    for cmd in binwalk dd xz cpio; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            log_error "Required command '$cmd' not found"
            exit 1
        fi
    done
    
    log_info "Prerequisites check passed"
}

# Extract initramfs from kernel using binwalk
extract_initramfs() {
    log_info "Extracting initramfs from kernel..."
    
    # Create working directory
    mkdir -p "$WORK_DIR"
    mkdir -p "$INITRAMFS_DIR"
    
    # Stage 1: Find gzip offset using binwalk
    log_info "Stage 1: Finding gzip offset..."
    local gzip_offset
    gzip_offset=$(binwalk "$KERNEL_FILE" | grep "gzip compressed data" | head -1 | awk '{print $1}')
    
    if [ -z "$gzip_offset" ]; then
        log_error "Could not find gzip offset in kernel"
        exit 1
    fi
    
    log_info "Gzip offset: $gzip_offset"
    
    # Stage 1: Decompress kernel
    log_info "Stage 1: Decompressing kernel..."
    local decompressed_kernel="$WORK_DIR/decompressed_kernel.bin"
    
    # Try to decompress, allowing for trailing garbage
    if ! dd if="$KERNEL_FILE" bs=1 skip="$gzip_offset" 2>/dev/null | gunzip > "$decompressed_kernel" 2>/dev/null; then
        log_warn "Standard decompression failed, trying with --force option..."
        dd if="$KERNEL_FILE" bs=1 skip="$gzip_offset" 2>/dev/null | gunzip --force > "$decompressed_kernel" 2>/dev/null || true
    fi
    
    if [ ! -f "$decompressed_kernel" ] || [ ! -s "$decompressed_kernel" ]; then
        log_error "Failed to decompress kernel"
        log_info "Checking if decompressed file exists and has content..."
        if [ -f "$decompressed_kernel" ]; then
            local file_size=$(stat -c%s "$decompressed_kernel" 2>/dev/null || echo "0")
            log_info "Decompressed file size: $file_size bytes"
        fi
        exit 1
    fi
    
    local decompressed_size=$(stat -c%s "$decompressed_kernel")
    log_info "Kernel decompressed successfully (${decompressed_size} bytes)"
    
    # Stage 2: Find XZ offset using binwalk
    log_info "Stage 2: Finding XZ offset..."
    local xz_offset
    xz_offset=$(binwalk "$decompressed_kernel" | grep "XZ compressed data" | head -1 | awk '{print $1}')
    
    if [ -z "$xz_offset" ]; then
        log_error "Could not find XZ offset in decompressed kernel"
        exit 1
    fi
    
    log_info "XZ offset: $xz_offset"
    
    # Stage 2: Extract XZ cpio archive
    log_info "Stage 2: Extracting XZ cpio archive..."
    if ! dd if="$decompressed_kernel" bs=1 skip="$xz_offset" 2>/dev/null | xz -dc 2>/dev/null | cpio -idm -D "$INITRAMFS_DIR" 2>/dev/null; then
        log_warn "Some cpio extraction errors occurred (this is expected for ChromeOS initramfs)"
        log_info "Continuing with extraction..."
    fi
    
    if [ ! -d "$INITRAMFS_DIR" ] || [ -z "$(ls -A "$INITRAMFS_DIR" 2>/dev/null)" ]; then
        log_error "Failed to extract initramfs - no files found in extraction directory"
        exit 1
    fi
    
    log_info "Initramfs extracted successfully to: $INITRAMFS_DIR"
    
    # List some key files to verify extraction
    log_info "Key files in extracted initramfs:"
    if [ -f "$INITRAMFS_DIR/init" ]; then
        log_info "  - init script found"
    fi
    if [ -d "$INITRAMFS_DIR/bin" ]; then
        log_info "  - bin directory found"
    fi
    if [ -d "$INITRAMFS_DIR/sbin" ]; then
        log_info "  - sbin directory found"
    fi
    if [ -d "$INITRAMFS_DIR/lib" ]; then
        log_info "  - lib directory found"
    fi
}

# Cleanup function
cleanup() {
    log_info "Cleaning up..."
    if [ -d "$WORK_DIR" ]; then
        rm -rf "$WORK_DIR"
    fi
}

# Main function
main() {
    log_info "Starting initramfs extraction process..."
    
    # Set up cleanup trap
    trap cleanup EXIT
    
    # Check prerequisites
    check_prerequisites
    
    # Extract initramfs
    extract_initramfs
    
    log_info "Initramfs extraction completed successfully!"
    log_info "Extracted initramfs available at: $INITRAMFS_DIR"
}

# Run main function
main "$@"