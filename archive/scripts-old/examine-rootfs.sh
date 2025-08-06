#!/usr/bin/env bash

# --- Script to Examine and Report Rootfs Structure After Build ---
#
# This script mounts the built shimboot NixOS image and examines the rootfs
# structure, reporting on files, directories, and symlinks.
#
# Usage: ./scripts/examine-rootfs.sh [OPTIONS]
#
# Options:
#   -i, --image PATH    Path to the image file (default: ./shimboot_nixos.bin)
#   -o, --output PATH   Path to output report file (default: rootfs-report.txt)
#   -h, --help          Show this help message
#
# Example:
#   ./scripts/examine-rootfs.sh
#   ./scripts/examine-rootfs.sh --image ./custom-image.bin --output custom-report.txt

set -euo pipefail

# Default values
IMAGE_PATH="./shimboot_nixos.bin"
OUTPUT_FILE="rootfs-report.txt"
MOUNT_POINT=""
LOOP_DEVICE=""

# --- Helper Functions ---

print_info() {
    echo "[INFO] $1" | tee -a "$OUTPUT_FILE"
}

print_error() {
    echo "[ERROR] $1" >&2
    echo "[ERROR] $1" >> "$OUTPUT_FILE"
}

print_debug() {
    if [[ "${DEBUG:-0}" == "1" ]]; then
        echo "[DEBUG] $1" | tee -a "$OUTPUT_FILE"
    fi
}

cleanup() {
    print_debug "Cleaning up..."
    
    # Unmount if mounted
    if [[ -n "$MOUNT_POINT" ]] && mountpoint -q "$MOUNT_POINT" 2>/dev/null; then
        print_debug "Unmounting $MOUNT_POINT"
        udisksctl unmount -b "${LOOP_DEVICE}p4" >/dev/null 2>&1 || true
    fi
    
    # Delete loop device if created
    if [[ -n "$LOOP_DEVICE" ]] && [[ -b "$LOOP_DEVICE" ]]; then
        print_debug "Deleting loop device $LOOP_DEVICE"
        udisksctl loop-delete -b "$LOOP_DEVICE" >/dev/null 2>&1 || true
    fi
    
    # Remove temporary mount point
    if [[ -n "$MOUNT_POINT" ]] && [[ -d "$MOUNT_POINT" ]]; then
        print_debug "Removing temporary mount point $MOUNT_POINT"
        rmdir "$MOUNT_POINT" 2>/dev/null || true
    fi
}

# --- Argument Parsing ---

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -i|--image)
                IMAGE_PATH="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_FILE="$2"
                shift 2
                ;;
            -h|--help)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  -i, --image PATH    Path to the image file (default: ./shimboot_nixos.bin)"
                echo "  -o, --output PATH   Path to output report file (default: rootfs-report.txt)"
                echo "  -h, --help          Show this help message"
                echo ""
                echo "Environment Variables:"
                echo "  DEBUG=1             Enable debug output"
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
}

# --- Main Functions ---

check_prerequisites() {
    print_info "Checking prerequisites..."
    
    # Check required commands
    for cmd in udisksctl fdisk ls grep; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            print_error "Required command '$cmd' not found"
            exit 1
        fi
        print_debug "✓ $cmd found at $(command -v "$cmd")"
    done
    
    # Check if image file exists
    if [[ ! -f "$IMAGE_PATH" ]]; then
        print_error "Image file not found: $IMAGE_PATH"
        exit 1
    fi
    print_debug "✓ Image file exists: $IMAGE_PATH"
}

mount_image() {
    print_info "Mounting image filesystem..."
    
    # Create temporary mount point
    MOUNT_POINT=$(mktemp -d)
    print_debug "Created temporary mount point: $MOUNT_POINT"
    
    # Setup loop device
    print_debug "Setting up loop device for $IMAGE_PATH"
    local loop_output
    loop_output=$(udisksctl loop-setup -f "$IMAGE_PATH")
    print_debug "udisksctl output: $loop_output"
    LOOP_DEVICE=$(echo "$loop_output" | awk '{print $5}' | tr -d '.')
    if [[ -z "$LOOP_DEVICE" ]]; then
        print_error "Failed to setup loop device"
        exit 1
    fi
    print_debug "Loop device created: $LOOP_DEVICE"
    
    # Verify the loop device exists
    if [[ ! -b "$LOOP_DEVICE" ]]; then
        print_error "Loop device $LOOP_DEVICE is not a block device"
        exit 1
    fi
    
    # Mount the rootfs partition (partition 4)
    print_debug "Mounting rootfs partition ${LOOP_DEVICE}p4"
    if ! udisksctl mount -b "${LOOP_DEVICE}p4" >/dev/null 2>&1; then
        print_error "Failed to mount rootfs partition"
        exit 1
    fi
    
    # Find the actual mount point
    MOUNT_POINT=$(findmnt -n -o TARGET --source "${LOOP_DEVICE}p4")
    print_debug "Rootfs mounted at: $MOUNT_POINT"
}

examine_rootfs_structure() {
    print_info "Examining rootfs structure..."
    
    {
        echo "=== Rootfs Structure Report ==="
        echo "Generated: $(date)"
        echo "Image: $IMAGE_PATH"
        echo ""
        echo "## Top-level Files and Directories:"
        echo ""
    } > "$OUTPUT_FILE"
    
    # List all top-level items with details
    cd "$MOUNT_POINT"
    ls -la | while read -r line; do
        echo "$line" >> "$OUTPUT_FILE"
    done
    
    echo "" >> "$OUTPUT_FILE"
}

examine_symlinks() {
    print_info "Examining symlinks..."
    
    {
        echo "## Symlinks:"
        echo ""
    } >> "$OUTPUT_FILE"
    
    # Find all symlinks in the rootfs
    cd "$MOUNT_POINT"
    find . -maxdepth 2 -type l -exec ls -lad {} \; 2>/dev/null | while read -r line; do
        echo "$line" >> "$OUTPUT_FILE"
    done || true
    
    echo "" >> "$OUTPUT_FILE"
}

examine_important_directories() {
    print_info "Examining important directories..."
    
    local important_dirs=("bin" "sbin" "usr/bin" "usr/sbin" "etc" "lib" "lib64")
    
    {
        echo "## Important Directories:"
        echo ""
    } >> "$OUTPUT_FILE"
    
    for dir in "${important_dirs[@]}"; do
        if [[ -d "$MOUNT_POINT/$dir" ]]; then
            {
                echo "### $dir/"
                echo ""
                ls -la "$MOUNT_POINT/$dir" | head -20 >> "$OUTPUT_FILE" || true
                if [[ $(ls -la "$MOUNT_POINT/$dir" 2>/dev/null | wc -l) -gt 20 ]]; then
                    echo "... (truncated)" >> "$OUTPUT_FILE"
                fi
                echo ""
            } >> "$OUTPUT_FILE"
        fi
    done
}

generate_summary() {
    print_info "Generating summary..."
    
    local file_count dir_count symlink_count
    
    file_count=$(find "$MOUNT_POINT" -maxdepth 1 -type f | wc -l)
    dir_count=$(find "$MOUNT_POINT" -maxdepth 1 -type d | wc -l)
    symlink_count=$(find "$MOUNT_POINT" -maxdepth 1 -type l | wc -l)
    
    {
        echo "## Summary:"
        echo ""
        echo "- Total top-level files: $file_count"
        echo "- Total top-level directories: $dir_count"
        echo "- Total top-level symlinks: $symlink_count"
        echo ""
        echo "=== End of Report ==="
    } >> "$OUTPUT_FILE"
}

display_report() {
    print_info "Displaying report to shell:"
    echo ""
    cat "$OUTPUT_FILE"
    echo ""
}

# --- Main Function ---

main() {
    # Parse command line arguments
    parse_args "$@"
    
    # Initialize output file
    echo "Rootfs Structure Examination Report" > "$OUTPUT_FILE"
    echo "Started at: $(date)" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    
    # Set up cleanup trap
    trap cleanup EXIT
    
    # Execute main functions
    check_prerequisites
    mount_image
    examine_rootfs_structure
    examine_symlinks
    examine_important_directories
    generate_summary
    
    print_info "Report generated successfully: $OUTPUT_FILE"
    
    # Display the report to shell
    display_report
    
    print_info "Rootfs examination complete."
}

# --- Run Main Function ---

main "$@"