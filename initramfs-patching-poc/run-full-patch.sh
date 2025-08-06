#!/usr/bin/env bash

# Master Script for Complete Initramfs Patching Workflow
# This script orchestrates the entire initramfs patching process

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/run-full-patch.log"

# Logging functions
log_info() {
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOG_FILE"
}

log_warn() {
    echo "[WARN] $(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOG_FILE" >&2
}

log_debug() {
    if [[ "${DEBUG:-0}" == "1" ]]; then
        echo "[DEBUG] $(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOG_FILE"
    fi
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if required scripts exist
    local required_scripts=(
        "extract-kernel.sh"
        "extract-initramfs.sh"
        "patch-initramfs.sh"
        "test-patched-initramfs.sh"
    )
    
    for script in "${required_scripts[@]}"; do
        if [ ! -f "$SCRIPT_DIR/$script" ]; then
            log_error "Required script not found: $script"
            exit 1
        fi
        if [ ! -x "$SCRIPT_DIR/$script" ]; then
            log_error "Script not executable: $script"
            exit 1
        fi
    done
    
    # Check if data directory exists
    if [ ! -d "$SCRIPT_DIR/../data" ]; then
        log_error "Data directory not found: $SCRIPT_DIR/../data"
        exit 1
    fi
    
    # Check if shim.bin exists
    if [ ! -f "$SCRIPT_DIR/../data/shim.bin" ]; then
        log_error "shim.bin not found: $SCRIPT_DIR/../data/shim.bin"
        exit 1
    fi
    
    # Check if bootloader directory exists
    if [ ! -d "$SCRIPT_DIR/../bootloader" ]; then
        log_error "Bootloader directory not found: $SCRIPT_DIR/../bootloader"
        exit 1
    fi
    
    log_info "Prerequisites check passed"
}

# Clean up previous work
cleanup_previous_work() {
    log_info "Cleaning up previous work..."
    
    # Remove extracted kernel if it exists
    if [ -f "$SCRIPT_DIR/kernel-extracted" ]; then
        rm -f "$SCRIPT_DIR/kernel-extracted"
        log_info "Removed previous kernel extraction"
    fi
    
    # Remove extracted initramfs if it exists
    if [ -d "$SCRIPT_DIR/initramfs-extracted" ]; then
        rm -rf "$SCRIPT_DIR/initramfs-extracted"
        log_info "Removed previous initramfs extraction"
    fi
    
    # Remove log files if they exist
    local log_files=(
        "$SCRIPT_DIR/extract-kernel.log"
        "$SCRIPT_DIR/extract-initramfs.log"
        "$SCRIPT_DIR/patch-initramfs.log"
        "$SCRIPT_DIR/test-patched-initramfs.log"
        "$SCRIPT_DIR/test-results.txt"
    )
    
    for log_file in "${log_files[@]}"; do
        if [ -f "$log_file" ]; then
            rm -f "$log_file"
            log_info "Removed log file: $log_file"
        fi
    done
    
    log_info "Cleanup completed"
}

# Step 1: Extract kernel
extract_kernel() {
    log_info "Step 1: Extracting kernel..."
    
    if ! "$SCRIPT_DIR/extract-kernel.sh"; then
        log_error "Kernel extraction failed"
        exit 1
    fi
    
    log_info "Kernel extraction completed successfully"
}

# Step 2: Extract initramfs
extract_initramfs() {
    log_info "Step 2: Extracting initramfs..."
    
    if ! "$SCRIPT_DIR/extract-initramfs.sh"; then
        log_error "Initramfs extraction failed"
        exit 1
    fi
    
    log_info "Initramfs extraction completed successfully"
}

# Step 3: Patch initramfs
patch_initramfs() {
    log_info "Step 3: Patching initramfs..."
    
    if ! "$SCRIPT_DIR/patch-initramfs.sh"; then
        log_error "Initramfs patching failed"
        exit 1
    fi
    
    log_info "Initramfs patching completed successfully"
}

# Step 4: Test patched initramfs
test_patched_initramfs() {
    log_info "Step 4: Testing patched initramfs..."
    
    if ! "$SCRIPT_DIR/test-patched-initramfs.sh"; then
        log_error "Patched initramfs test failed"
        exit 1
    fi
    
    log_info "Patched initramfs test completed successfully"
}

# Generate summary report
generate_summary_report() {
    log_info "Generating summary report..."
    
    local report_file="$SCRIPT_DIR/patch-summary-report.txt"
    
    {
        echo "=== INITRAMFS PATCHING SUMMARY REPORT ==="
        echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "Working Directory: $SCRIPT_DIR"
        echo ""
        echo "=== EXECUTION STEPS ==="
        echo "1. Kernel Extraction: COMPLETED"
        echo "2. Initramfs Extraction: COMPLETED"
        echo "3. Initramfs Patching: COMPLETED"
        echo "4. Patched Initramfs Testing: COMPLETED"
        echo ""
        echo "=== ARTIFACTS CREATED ==="
        echo "- Extracted Kernel: $SCRIPT_DIR/kernel-extracted"
        echo "- Patched Initramfs: $SCRIPT_DIR/initramfs-extracted/"
        echo "- Test Results: $SCRIPT_DIR/test-results.txt"
        echo ""
        echo "=== LOG FILES ==="
        echo "- Master Log: $LOG_FILE"
        echo "- Kernel Extraction Log: $SCRIPT_DIR/extract-kernel.log"
        echo "- Initramfs Extraction Log: $SCRIPT_DIR/extract-initramfs.log"
        echo "- Initramfs Patching Log: $SCRIPT_DIR/patch-initramfs.log"
        echo "- Test Log: $SCRIPT_DIR/test-patched-initramfs.log"
        echo ""
        echo "=== STATUS ==="
        echo "Overall Status: SUCCESS"
        echo "All steps completed successfully!"
        echo ""
        echo "=== NEXT STEPS ==="
        echo "The patched initramfs is ready for integration into the NixOS build system."
        echo "Proceed with creating Nix derivations for declarative initramfs patching."
    } > "$report_file"
    
    log_info "Summary report generated: $report_file"
}

# Main function
main() {
    log_info "Starting complete initramfs patching workflow..."
    
    # Clear log file
    > "$LOG_FILE"
    
    # Check prerequisites
    check_prerequisites
    
    # Clean up previous work
    cleanup_previous_work
    
    # Execute all steps
    extract_kernel
    extract_initramfs
    patch_initramfs
    test_patched_initramfs
    
    # Generate summary report
    generate_summary_report
    
    log_info "Complete initramfs patching workflow finished successfully!"
    log_info "Master log saved to: $LOG_FILE"
    log_info "Summary report saved to: $SCRIPT_DIR/patch-summary-report.txt"
}

# Handle command line arguments
case "${1:-}" in
    "clean")
        log_info "Cleaning up previous work..."
        cleanup_previous_work
        log_info "Cleanup completed"
        exit 0
        ;;
    "help"|"-h"|"--help")
        echo "Usage: $0 [clean|help]"
        echo ""
        echo "Commands:"
        echo "  clean  - Clean up previous work without running the workflow"
        echo "  help   - Show this help message"
        echo ""
        echo "Environment Variables:"
        echo "  DEBUG=1 - Enable debug logging"
        exit 0
        ;;
    "")
        # No argument, run main workflow
        ;;
    *)
        log_error "Unknown argument: $1"
        echo "Use '$0 help' for usage information"
        exit 1
        ;;
esac

# Run main function
main "$@"