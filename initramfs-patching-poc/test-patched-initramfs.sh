#!/usr/bin/env bash

# Test Script for Patched Initramfs
# This script verifies that the patched initramfs contains all required bootloader components

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INITRAMFS_DIR="${SCRIPT_DIR}/initramfs-extracted"
LOG_FILE="${SCRIPT_DIR}/test-patched-initramfs.log"
TEST_RESULTS_FILE="${SCRIPT_DIR}/test-results.txt"

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

# Test result tracking
test_passed=0
test_failed=0

record_test_result() {
    local test_name="$1"
    local result="$2"
    local message="$3"
    
    echo "[$result] $test_name: $message" | tee -a "$TEST_RESULTS_FILE"
    
    if [ "$result" = "PASS" ]; then
        test_passed=$((test_passed + 1))
    else
        test_failed=$((test_failed + 1))
    fi
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if initramfs directory exists
    if [ ! -d "$INITRAMFS_DIR" ]; then
        log_error "Initramfs directory not found: $INITRAMFS_DIR"
        exit 1
    fi
    
    # Check if init script exists
    if [ ! -f "$INITRAMFS_DIR/init" ]; then
        log_error "Init script not found: $INITRAMFS_DIR/init"
        exit 1
    fi
    
    log_info "Prerequisites check passed"
}

# Test 1: Check if init script exists and is executable
test_init_script() {
    log_info "Test 1: Checking init script..."
    
    local init_script="$INITRAMFS_DIR/init"
    
    if [ ! -f "$init_script" ]; then
        record_test_result "Init Script" "FAIL" "File not found"
        return
    fi
    
    if [ ! -x "$init_script" ]; then
        record_test_result "Init Script" "FAIL" "Not executable"
        return
    fi
    
    record_test_result "Init Script" "PASS" "Exists and executable"
}

# Test 2: Check if init script contains bootstrap.sh execution
test_bootstrap_execution() {
    log_info "Test 2: Checking bootstrap.sh execution in init script..."
    
    local init_script="$INITRAMFS_DIR/init"
    
    if ! grep -q "bootstrap.sh" "$init_script"; then
        record_test_result "Bootstrap Execution" "FAIL" "bootstrap.sh not found in init script"
        return
    fi
    
    if ! grep -q "exec /bin/bootstrap.sh" "$init_script"; then
        record_test_result "Bootstrap Execution" "FAIL" "exec /bin/bootstrap.sh not found in init script"
        return
    fi
    
    record_test_result "Bootstrap Execution" "PASS" "bootstrap.sh execution found in init script"
}

# Test 3: Check if bootloader files exist
test_bootloader_files() {
    log_info "Test 3: Checking bootloader files..."
    
    local required_files=(
        "bin/bootstrap.sh"
        "bin/init"
        "opt/crossystem"
        "opt/mount-encrypted"
        "opt/.shimboot_version"
    )
    
    local all_files_exist=true
    
    for file in "${required_files[@]}"; do
        if [ ! -f "$INITRAMFS_DIR/$file" ]; then
            record_test_result "Bootloader File: $file" "FAIL" "File not found"
            all_files_exist=false
        else
            record_test_result "Bootloader File: $file" "PASS" "File exists"
        fi
    done
    
    if [ "$all_files_exist" = true ]; then
        record_test_result "Bootloader Files" "PASS" "All required files exist"
    else
        record_test_result "Bootloader Files" "FAIL" "Some files missing"
    fi
}

# Test 4: Check if bootloader scripts are executable
test_executable_scripts() {
    log_info "Test 4: Checking executable bootloader scripts..."
    
    local executable_files=(
        "bin/bootstrap.sh"
        "bin/init"
    )
    
    local all_executable=true
    
    for file in "${executable_files[@]}"; do
        if [ ! -x "$INITRAMFS_DIR/$file" ]; then
            record_test_result "Executable Script: $file" "FAIL" "Not executable"
            all_executable=false
        else
            record_test_result "Executable Script: $file" "PASS" "Executable"
        fi
    done
    
    if [ "$all_executable" = true ]; then
        record_test_result "Executable Scripts" "PASS" "All scripts executable"
    else
        record_test_result "Executable Scripts" "FAIL" "Some scripts not executable"
    fi
}

# Test 5: Check if directory structure is correct
test_directory_structure() {
    log_info "Test 5: Checking directory structure..."
    
    local required_dirs=(
        "bin"
        "sbin"
        "lib"
        "lib64"
        "opt"
        "proc"
        "sys"
        "dev"
        "var"
        "run"
        "mnt"
        "root"
    )
    
    local all_dirs_exist=true
    
    for dir in "${required_dirs[@]}"; do
        if [ ! -d "$INITRAMFS_DIR/$dir" ]; then
            record_test_result "Directory: $dir" "FAIL" "Directory not found"
            all_dirs_exist=false
        else
            record_test_result "Directory: $dir" "PASS" "Directory exists"
        fi
    done
    
    if [ "$all_dirs_exist" = true ]; then
        record_test_result "Directory Structure" "PASS" "All required directories exist"
    else
        record_test_result "Directory Structure" "FAIL" "Some directories missing"
    fi
}

# Test 6: Check if backup was created
test_backup() {
    log_info "Test 6: Checking backup creation..."
    
    if [ ! -f "$INITRAMFS_DIR/init.backup" ]; then
        record_test_result "Backup Creation" "FAIL" "Backup file not found"
        return
    fi
    
    record_test_result "Backup Creation" "PASS" "Backup file exists"
}

# Test 7: Check if shimboot version file exists
test_shimboot_version() {
    log_info "Test 7: Checking shimboot version file..."
    
    local version_file="$INITRAMFS_DIR/opt/.shimboot_version"
    
    if [ ! -f "$version_file" ]; then
        record_test_result "Shimboot Version" "FAIL" "Version file not found"
        return
    fi
    
    local version_content
    version_content=$(cat "$version_file")
    
    if [ -z "$version_content" ]; then
        record_test_result "Shimboot Version" "FAIL" "Version file is empty"
        return
    fi
    
    record_test_result "Shimboot Version" "PASS" "Version: $version_content"
}

# Test 8: Check if essential binaries exist
test_essential_binaries() {
    log_info "Test 8: Checking essential binaries..."
    
    local essential_binaries=(
        "bin/busybox"
        "bin/sh"
        "bin/cgpt"
        "bin/crossystem"
        "sbin/busybox"
        "sbin/sh"
        "sbin/cgpt"
        "sbin/crossystem"
    )
    
    local all_binaries_exist=true
    
    for binary in "${essential_binaries[@]}"; do
        if [ ! -f "$INITRAMFS_DIR/$binary" ]; then
            record_test_result "Essential Binary: $binary" "FAIL" "Binary not found"
            all_binaries_exist=false
        else
            record_test_result "Essential Binary: $binary" "PASS" "Binary exists"
        fi
    done
    
    if [ "$all_binaries_exist" = true ]; then
        record_test_result "Essential Binaries" "PASS" "All essential binaries exist"
    else
        record_test_result "Essential Binaries" "FAIL" "Some essential binaries missing"
    fi
}

# Generate test summary
generate_test_summary() {
    log_info "Generating test summary..."
    
    local total_tests=$((test_passed + test_failed))
    
    echo "" | tee -a "$TEST_RESULTS_FILE"
    echo "=== TEST SUMMARY ===" | tee -a "$TEST_RESULTS_FILE"
    echo "Total Tests: $total_tests" | tee -a "$TEST_RESULTS_FILE"
    echo "Passed: $test_passed" | tee -a "$TEST_RESULTS_FILE"
    echo "Failed: $test_failed" | tee -a "$TEST_RESULTS_FILE"
    
    if [ "$test_failed" -eq 0 ]; then
        echo "Status: ALL TESTS PASSED" | tee -a "$TEST_RESULTS_FILE"
        log_info "All tests passed successfully!"
    else
        echo "Status: SOME TESTS FAILED" | tee -a "$TEST_RESULTS_FILE"
        log_error "Some tests failed. Please check the test results."
    fi
}

# Main function
main() {
    log_info "Starting patched initramfs verification..."
    
    # Clear log and results files
    > "$LOG_FILE"
    > "$TEST_RESULTS_FILE"
    
    # Check prerequisites
    check_prerequisites
    
    # Run all tests
    test_init_script
    test_bootstrap_execution
    test_bootloader_files
    test_executable_scripts
    test_directory_structure
    test_backup
    test_shimboot_version
    test_essential_binaries
    
    # Generate test summary
    generate_test_summary
    
    log_info "Test results saved to: $TEST_RESULTS_FILE"
    log_info "Test logs saved to: $LOG_FILE"
    
    # Exit with appropriate code
    if [ "$test_failed" -gt 0 ]; then
        exit 1
    fi
}

# Run main function
main "$@"