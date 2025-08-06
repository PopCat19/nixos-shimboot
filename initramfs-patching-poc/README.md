# Initramfs Patching Proof of Concept

This directory contains a complete proof of concept for patching ChromeOS initramfs with shimboot bootloader files. The scripts demonstrate the entire workflow from kernel extraction to final verification.

## Overview

The proof of concept consists of the following components:

1. **Kernel Extraction** (`extract-kernel.sh`) - Extracts the kernel partition from the ChromeOS shim image
2. **Initramfs Extraction** (`extract-initramfs.sh`) - Extracts the initramfs from the kernel using binwalk and decompression tools
3. **Initramfs Patching** (`patch-initramfs.sh`) - Injects shimboot bootloader files into the extracted initramfs
4. **Testing** (`test-patched-initramfs.sh`) - Verifies that the patched initramfs contains all required components
5. **Master Script** (`run-full-patch.sh`) - Orchestrates the entire workflow

## Prerequisites

The following tools must be available in your system:
- `cgpt` - ChromeOS GPT utility
- `binwalk` - Firmware analysis tool
- `dd` - Data duplicator utility
- `gzip` / `gunzip` - Compression utilities
- `xz` - XZ compression utility
- `cpio` - Archive utility
- `jq` - JSON processor

## Usage

### Running the Complete Workflow

To execute the entire initramfs patching workflow:

```bash
./run-full-patch.sh
```

This will:
1. Extract the kernel from `../data/shim.bin`
2. Extract the initramfs from the kernel
3. Patch the initramfs with bootloader files from `../bootloader/`
4. Run comprehensive tests to verify the patching
5. Generate a summary report

### Running Individual Scripts

You can also run individual scripts for testing or debugging:

```bash
# Extract kernel only
./extract-kernel.sh

# Extract initramfs only (requires kernel to be extracted first)
./extract-initramfs.sh

# Patch initramfs only (requires initramfs to be extracted first)
./patch-initramfs.sh

# Test patched initramfs only
./test-patched-initramfs.sh
```

### Cleaning Up

To clean up previous work without running the workflow:

```bash
./run-full-patch.sh clean
```

### Getting Help

```bash
./run-full-patch.sh help
```

## Artifacts Created

The workflow creates the following artifacts:

- `kernel-extracted` - Extracted kernel partition
- `initramfs-extracted/` - Patched initramfs directory structure
- `test-results.txt` - Detailed test results
- `patch-summary-report.txt` - Summary report of the entire workflow
- Various log files for debugging

## Test Coverage

The test script verifies 35 different aspects of the patched initramfs:

1. **Init Script Verification**
   - Script exists and is executable
   - Contains bootstrap.sh execution

2. **Bootloader Files**
   - All required bootloader files exist
   - Scripts are executable

3. **Directory Structure**
   - All required directories exist
   - Proper filesystem structure

4. **Backup and Versioning**
   - Original init script backed up
   - Shimboot version file present

5. **Essential Binaries**
   - All critical binaries exist in both `/bin` and `/sbin`

## Integration with NixOS

This proof of concept serves as the foundation for creating declarative Nix derivations. The next steps involve:

1. Creating Nix derivations for each step of the process
2. Building an `initramfs-patching.nix` module
3. Integrating the module into the existing flake structure
4. Testing the complete declarative workflow

## Technical Details

### Kernel Extraction Process

1. Uses `cgpt` to locate the KERN-A partition
2. Extracts the partition using `dd`
3. Handles ChromeOS-specific partition attributes

### Initramfs Extraction Process

1. Uses `binwalk` to find gzip offset in the kernel
2. Decompresses the kernel (with fallback for ChromeOS compression)
3. Uses `binwalk` to find XZ offset in the decompressed kernel
4. Extracts the XZ-compressed cpio archive
5. Handles expected ChromeOS extraction warnings

### Initramfs Patching Process

1. Copies bootloader files from `../bootloader/`
2. Modifies the init script to execute `bootstrap.sh`
3. Makes all bootloader scripts executable
4. Verifies the patching process

## Error Handling

All scripts include comprehensive error handling:
- Prerequisites checking
- Graceful failure with informative error messages
- Detailed logging for debugging
- Expected warnings for ChromeOS-specific quirks

## Logging

Each script generates detailed logs:
- Individual script logs for each step
- Master log for the complete workflow
- Test results with pass/fail status
- Summary report with overall status

## Next Steps

The proof of concept is ready for integration into the NixOS build system. The next phase involves:

1. Creating Nix derivations to replace the imperative scripts
2. Building a declarative initramfs patching module
3. Integrating with the existing flake structure
4. End-to-end testing of the declarative approach

## Files

- `extract-kernel.sh` - Kernel extraction script
- `extract-initramfs.sh` - Initramfs extraction script
- `patch-initramfs.sh` - Initramfs patching script
- `test-patched-initramfs.sh` - Comprehensive test script
- `run-full-patch.sh` - Master orchestration script
- `README.md` - This documentation
- `.gitignore` - Git ignore rules