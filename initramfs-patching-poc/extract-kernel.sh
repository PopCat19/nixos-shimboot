#!/usr/bin/env bash

# Kernel extraction script for ChromeOS shim
# Adapted from archive/scripts-old/lib/harvest.sh

set -e

# Configuration
SHIM_FILE="../data/shim.bin"
KERNEL_FILE="./extracted-kernel"
WORK_DIR="./temp"

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
    
    # Check if shim file exists
    if [ ! -f "$SHIM_FILE" ]; then
        log_error "Shim file not found at $SHIM_FILE"
        exit 1
    fi
    
    # Check required commands
    for cmd in cgpt dd; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            log_error "Required command '$cmd' not found"
            exit 1
        fi
    done
    
    log_info "Prerequisites check passed"
}

# Extract kernel partition (KERN-A)
extract_kernel_partition() {
    log_info "Extracting kernel partition (KERN-A) from $SHIM_FILE"
    
    # Get kernel partition info using cgpt
    log_info "Running: cgpt show -i 2 \"$SHIM_FILE\""
    local cgpt_output
    cgpt_output=$(cgpt show -i 2 "$SHIM_FILE")
    
    if [ -z "$cgpt_output" ]; then
        log_error "Failed to get partition information from $SHIM_FILE"
        exit 1
    fi
    
    log_info "CGPT output:"
    echo "$cgpt_output"
    
    # Extract partition start and size
    local part_start part_size
    part_start=$(echo "$cgpt_output" | awk 'NR==2 {print $1}')
    part_size=$(echo "$cgpt_output" | awk 'NR==2 {print $2}')
    
    if [ -z "$part_start" ] || [ -z "$part_size" ]; then
        log_error "Failed to parse partition start/size from cgpt output"
        exit 1
    fi
    
    log_info "Partition start: $part_start, size: $part_size"
    
    # Extract kernel with dd
    log_info "Extracting kernel with dd..."
    dd if="$SHIM_FILE" of="$KERNEL_FILE" bs=512 skip="$part_start" count="$part_size" status=progress
    
    if [ ! -f "$KERNEL_FILE" ]; then
        log_error "Failed to extract kernel to $KERNEL_FILE"
        exit 1
    fi
    
    local kernel_size=$(stat -c%s "$KERNEL_FILE")
    log_info "Kernel extracted successfully: $KERNEL_FILE (${kernel_size} bytes)"
}

# Create working directory
setup_work_dir() {
    log_info "Setting up working directory..."
    mkdir -p "$WORK_DIR"
    log_info "Working directory: $WORK_DIR"
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
    log_info "Starting kernel extraction process..."
    
    # Set up cleanup trap
    trap cleanup EXIT
    
    # Check prerequisites
    check_prerequisites
    
    # Setup working directory
    setup_work_dir
    
    # Extract kernel partition
    extract_kernel_partition
    
    log_info "Kernel extraction completed successfully!"
    log_info "Extracted kernel available at: $KERNEL_FILE"
}

# Run main function
main "$@"