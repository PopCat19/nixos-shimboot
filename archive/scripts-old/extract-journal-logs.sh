#!/usr/bin/env bash

# --- Script to Extract Journal Logs from User-Selectable Rootfs ---
#
# This script mounts a user-specified root filesystem device and extracts
# journal logs for debugging purposes.
#
# Usage: ./scripts/extract-journal-logs.sh [OPTIONS]
#
# Options:
#   -d, --device PATH    Device path (e.g., /dev/sdc4) (required)
#   -o, --output PATH    Output directory for extracted logs (default: ./journal-logs)
#   -h, --help           Show this help message
#
# Example:
#   ./scripts/extract-journal-logs.sh --device /dev/sdc4
#   ./scripts/extract-journal-logs.sh -d /dev/sdc4 -o /tmp/debug-logs

set -euo pipefail

# Source common utility functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# Default values
DEVICE_PATH=""
OUTPUT_DIR="./journal-logs"
MOUNT_POINT=""
TEMP_DIR=""

# --- Helper Functions ---

print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -d, --device PATH    Device path (e.g., /dev/sdc4) (required)"
    echo "  -o, --output PATH    Output directory for extracted logs (default: ./journal-logs)"
    echo "  -h, --help           Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  DEBUG=1              Enable debug output"
}

cleanup() {
    print_debug "Cleaning up..."
    
    # Unmount if mounted
    if [[ -n "$MOUNT_POINT" ]]; then
        unmount_if_mounted "$MOUNT_POINT"
    fi
    
    # Remove temporary directory
    if [[ -n "$TEMP_DIR" ]]; then
        remove_temp_dir "$TEMP_DIR"
    fi
    
    # Clean up sudo keepalive
    cleanup_sudo
}

# --- Argument Parsing ---

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--device)
                DEVICE_PATH="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -h|--help)
                print_usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                print_usage
                exit 1
                ;;
        esac
    done
    
    # Validate required arguments
    if [[ -z "$DEVICE_PATH" ]]; then
        print_error "Device path is required. Use -d or --device option."
        print_usage
        exit 1
    fi
}

# --- Main Functions ---

check_prerequisites() {
    print_info "Checking prerequisites..."
    
    # Check required commands
    for cmd in sudo mount umount find cp; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            print_error "Required command '$cmd' not found"
            exit 1
        fi
        print_debug "✓ $cmd found at $(command -v "$cmd")"
    done
    
    # Check if device exists
    if [[ ! -b "$DEVICE_PATH" ]]; then
        print_error "Device not found or not a block device: $DEVICE_PATH"
        exit 1
    fi
    print_debug "✓ Device exists: $DEVICE_PATH"
    
    # Check sudo access
    check_sudo
    keep_sudo_alive
}

mount_device() {
    print_info "Mounting device $DEVICE_PATH..."
    
    # Create temporary mount point
    TEMP_DIR=$(create_temp_dir "journal-extract")
    MOUNT_POINT="$TEMP_DIR/mount"
    mkdir -p "$MOUNT_POINT"
    print_debug "Created temporary mount point: $MOUNT_POINT"
    
    # Mount the device
    if ! sudo mount "$DEVICE_PATH" "$MOUNT_POINT"; then
        print_error "Failed to mount device $DEVICE_PATH"
        exit 1
    fi
    print_debug "Device mounted at: $MOUNT_POINT"
}

extract_journal_logs() {
    print_info "Extracting journal logs..."
    
    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    
    # Define possible journal locations
    local journal_locations=(
        "var/log/journal"
        "var/log/systemd"
        "log/journal"
        "log/systemd"
    )
    
    local found_journals=false
    
    for location in "${journal_locations[@]}"; do
        local journal_path="$MOUNT_POINT/$location"
        if [[ -d "$journal_path" ]]; then
            print_info "Found journal directory: $location"
            found_journals=true
            
            # Create output subdirectory for this journal location
            local output_subdir="$OUTPUT_DIR/${location//\//-}"
            mkdir -p "$output_subdir"
            
            # Copy journal files
            print_debug "Copying journal files from $journal_path to $output_subdir"
            if sudo cp -r "$journal_path"/* "$output_subdir/" 2>/dev/null; then
                print_info "✓ Successfully copied journal files from $location"
                
                # Change ownership of copied files to current user
                sudo chown -R "$(id -u):$(id -g)" "$output_subdir"
                
                # List copied files
                print_debug "Copied files:"
                find "$output_subdir" -type f -name "*.journal" | head -10 | while read -r file; do
                    print_debug "  - $(basename "$file")"
                done
                
                local file_count=$(find "$output_subdir" -type f -name "*.journal" | wc -l)
                print_info "  Copied $file_count journal files"
                
                # Extract text versions of journal files
                print_info "  Extracting text versions of journal files..."
                find "$output_subdir" -type f -name "*.journal" | while read -r journal_file; do
                    local base_name=$(basename "$journal_file" .journal)
                    local text_dir="$output_subdir/text-versions"
                    mkdir -p "$text_dir"
                    
                    # Check if journalctl is available
                    if command -v journalctl >/dev/null 2>&1; then
                        print_debug "    Creating text version of $base_name.journal"
                        
                        # Extract first 200 lines
                        local head_file="$text_dir/${base_name}_head.txt"
                        if journalctl -D "$output_subdir" --no-pager | head -200 > "$head_file" 2>/dev/null; then
                            print_info "    ✓ Created head version: $(basename "$head_file")"
                        else
                            print_error "    Failed to create head version for $base_name.journal"
                        fi
                        
                        # Extract last 200 lines
                        local tail_file="$text_dir/${base_name}_tail.txt"
                        if journalctl -D "$output_subdir" --no-pager | tail -200 > "$tail_file" 2>/dev/null; then
                            print_info "    ✓ Created tail version: $(basename "$tail_file")"
                        else
                            print_error "    Failed to create tail version for $base_name.journal"
                        fi
                    else
                        print_debug "    journalctl not available, skipping text extraction for $base_name.journal"
                    fi
                done
            else
                print_error "Failed to copy journal files from $location"
            fi
        fi
    done
    
    if [[ "$found_journals" == "false" ]]; then
        print_error "No journal directories found on device $DEVICE_PATH"
        print_info "Checked locations:"
        for location in "${journal_locations[@]}"; do
            print_info "  - $location"
        done
        exit 1
    fi
}

extract_system_logs() {
    print_info "Extracting additional system logs..."
    
    # Define common system log files
    local log_files=(
        "var/log/syslog"
        "var/log/messages"
        "var/log/kern.log"
        "var/log/auth.log"
        "var/log/dmesg"
        "log/syslog"
        "log/messages"
        "log/kern.log"
        "log/auth.log"
    )
    
    local logs_dir="$OUTPUT_DIR/system-logs"
    mkdir -p "$logs_dir"
    
    for log_file in "${log_files[@]}"; do
        local source_path="$MOUNT_POINT/$log_file"
        if [[ -f "$source_path" ]]; then
            local dest_file="$logs_dir/$(basename "$log_file")"
            print_info "Found system log: $log_file"
            
            if sudo cp "$source_path" "$dest_file" 2>/dev/null; then
                sudo chown "$(id -u):$(id -g)" "$dest_file"
                print_info "  ✓ Copied to $dest_file"
            else
                print_error "  Failed to copy $log_file"
            fi
        fi
    done
}

generate_summary() {
    print_info "Generating extraction summary..."
    
    local summary_file="$OUTPUT_DIR/EXTRACTION_SUMMARY.txt"
    
    {
        echo "Journal Logs Extraction Summary"
        echo "=============================="
        echo ""
        echo "Extraction Date: $(date)"
        echo "Source Device: $DEVICE_PATH"
        echo "Output Directory: $OUTPUT_DIR"
        echo ""
        echo "Extracted Journal Directories:"
        echo ""
        
        # List extracted journal directories
        find "$OUTPUT_DIR" -maxdepth 1 -type d -name "*journal*" | while read -r dir; do
            if [[ "$dir" != "$OUTPUT_DIR" ]]; then
                local dir_name=$(basename "$dir")
                local file_count=$(find "$dir" -type f -name "*.journal" 2>/dev/null | wc -l)
                echo "- $dir_name: $file_count journal files"
                
                # List text versions if they exist
                local text_dir="$dir/text-versions"
                if [[ -d "$text_dir" ]]; then
                    local head_count=$(find "$text_dir" -type f -name "*_head.txt" 2>/dev/null | wc -l)
                    local tail_count=$(find "$text_dir" -type f -name "*_tail.txt" 2>/dev/null | wc -l)
                    echo "  Text versions: $head_count head files, $tail_count tail files"
                fi
            fi
        done
        
        echo ""
        echo "Extracted System Logs:"
        echo ""
        
        # List extracted system logs
        if [[ -d "$OUTPUT_DIR/system-logs" ]]; then
            find "$OUTPUT_DIR/system-logs" -type f | while read -r log; do
                local log_name=$(basename "$log")
                local log_size=$(du -h "$log" | cut -f1)
                echo "- $log_name ($log_size)"
            done
        else
            echo "No system logs extracted"
        fi
        
        echo ""
        echo "Text Versions of Journal Logs:"
        echo ""
        
        # List text versions of journal logs
        local text_dirs=()
        while IFS= read -r -d '' dir; do
            text_dirs+=("$dir")
        done < <(find "$OUTPUT_DIR" -type d -name "text-versions" -print0 2>/dev/null)
        
        if [[ ${#text_dirs[@]} -gt 0 ]]; then
            for text_dir in "${text_dirs[@]}"; do
                local parent_dir=$(dirname "$text_dir")
                local parent_name=$(basename "$parent_dir")
                echo "From $parent_name:"
                
                # List head files
                find "$text_dir" -type f -name "*_head.txt" | while read -r head_file; do
                    local file_name=$(basename "$head_file")
                    local file_size=$(du -h "$head_file" | cut -f1)
                    echo "  - $file_name (first 200 lines, $file_size)"
                done
                
                # List tail files
                find "$text_dir" -type f -name "*_tail.txt" | while read -r tail_file; do
                    local file_name=$(basename "$tail_file")
                    local file_size=$(du -h "$tail_file" | cut -f1)
                    echo "  - $file_name (last 200 lines, $file_size)"
                done
            done
        else
            echo "No text versions extracted"
        fi
        
        echo ""
        echo "Extraction completed successfully."
        echo ""
        echo "To view journal logs, you can use:"
        echo "  journalctl -D $OUTPUT_DIR/var-log-journal [OPTIONS]"
        echo ""
        echo "Text versions can be viewed directly with any text viewer."
        
    } > "$summary_file"
    
    print_info "Summary saved to: $summary_file"
}

# --- Main Function ---

main() {
    # Parse command line arguments
    parse_args "$@"
    
    # Print banner
    print_info "Journal Logs Extraction Script"
    print_info "================================"
    
    # Set up cleanup trap
    trap cleanup EXIT
    
    # Execute main functions
    check_prerequisites
    mount_device
    extract_journal_logs
    extract_system_logs
    generate_summary
    
    print_info ""
    print_info "Journal logs extraction complete!"
    print_info "Output directory: $OUTPUT_DIR"
    print_info ""
    print_info "You can now analyze the extracted journal logs."
    print_info "To view journal logs, you can use:"
    print_info "  journalctl -D $OUTPUT_DIR/var-log-journal [OPTIONS]"
}

# --- Run Main Function ---

main "$@"