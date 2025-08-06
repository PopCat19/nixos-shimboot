# Phase 1: Initialization and Prerequisites

## Overview

The first phase of the old build process involved setting up the environment, validating prerequisites, and preparing for the component harvesting and assembly operations. This phase was critical for ensuring the build process had everything it needed to succeed.

## Configuration Setup

### Default Configuration Variables

The build process began by initializing a set of configuration variables with default values in [`config.sh`](../scripts-old/lib/config.sh):

```bash
# Project paths
PROJECT_ROOT="$(pwd)"
SHIM_FILE="$PROJECT_ROOT/data/shim.bin"
RECOVERY_FILE="$PROJECT_ROOT/data/recovery.bin"
KERNEL_FILE="$PROJECT_ROOT/data/kernel.bin"
BOOTLOADER_DIR="$PROJECT_ROOT/bootloader"
OUTPUT_PATH="$PROJECT_ROOT/shimboot_nixos.bin"
WIFI_CREDENTIALS_FILE="$PROJECT_ROOT/wifi-credentials.json"
WIFI_CREDENTIALS_EXAMPLE="$PROJECT_ROOT/wifi-credentials.json.example"

# Partition sizes (in MB)
STATE_PART_SIZE_MB=1
KERNEL_PART_SIZE_MB=32
BOOTLOADER_PART_SIZE_MB=32

# Mount points
SHIM_ROOTFS_MOUNT=""
RECOVERY_ROOTFS_MOUNT=""
NIXOS_SOURCE_MOUNT="/tmp/nixos_source_mount"
BOOTLOADER_MOUNT="/tmp/shim_bootloader"
ROOTFS_MOUNT="/tmp/new_rootfs"

# Temporary directories
TMP_DIR=""
FIRMWARE_DEST_PATH=""
MODPROBE_DEST_PATH=""
KMOD_DEST_PATH=""

# Loop devices
IMAGE_LOOP=""
SHIM_LOOP=""
RECOVERY_LOOP=""
NIXOS_LOOP=""

# Build options
USE_RECOVERY=false
LOGFILE="build-final-image.log"

# Systemd configuration
SYSTEMD_VERSION_LOCK="257.6"  # Lock to systemd version 257.6 for stability
SYSTEMD_REQUIRE_PATCHED=true  # Fail if no patched systemd is found
SYSTEMD_BINARY_PATH="/nix/store/31v77wh2wsmn44sqayd4f34rxh94d459-systemd-257.6/lib/systemd/systemd"
```

### Key Configuration Notes

1. **Partition Sizes**: The build process used fixed partition sizes that matched ChromeOS's standard layout:
   - STATE partition: 1MB (minimal size for system state)
   - KERNEL partition: 32MB (sufficient for custom kernel)
   - BOOTLOADER partition: 32MB (for shimboot bootloader)

2. **Systemd Version Lock**: The process was locked to systemd version 257.6, which was known to work with ChromeOS hardware. This was a critical stability requirement.

3. **Systemd Binary Path**: The build process expected a specific systemd binary path, which pointed to a patched version compatible with ChromeOS.

## Environment Validation

### Privilege Checking

The script first checked that it was NOT running as root:

```bash
check_not_root() {
  if [ "$EUID" -eq 0 ]; then
    print_error "Don't run this script as root! It will escalate privileges when needed."
    exit 1
  fi
}
```

**Key Note**: The script was designed to run as a regular user and would escalate privileges only when necessary using sudo. This approach improved security by limiting the operations that ran with root privileges.

### Command Availability Check

The script verified that all required commands were available:

```bash
REQUIRED_COMMANDS="nix cgpt binwalk nixos-generate jq hexdump strings fdisk tar gunzip git"

check_commands() {
  local commands="$1"
  print_info "Checking prerequisites..."
  
  for cmd in $commands; do
    if command -v $cmd >/dev/null; then
      print_debug "✓ $cmd found at $(command -v $cmd)"
    else
      print_error "✗ $cmd not found"
      exit 1
    fi
  done
}
```

**Critical Commands**:
- `nix`: The Nix package manager, essential for building NixOS
- `cgpt`: ChromeOS GPT utility for partition manipulation
- `binwalk`: Tool for analyzing and extracting firmware images
- `nixos-generate`: NixOS system image generation tool
- `jq`: JSON processor for parsing configuration files
- `hexdump`/`strings`: Binary file analysis tools
- `fdisk`: Disk partitioning utility
- `tar`/`gunzip`: Archive and compression tools
- `git`: Version control system

### File Existence Check

The script verified that required files existed:

```bash
REQUIRED_FILES="$SHIM_FILE $BOOTLOADER_DIR"

check_files() {
  local files="$1"
  
  for file in $files; do
    if [ -e "$file" ]; then
      print_debug "✓ $file exists"
    else
      print_error "✗ $file not found"
      exit 1
    fi
  done
}
```

**Required Files**:
- `shim.bin`: The ChromeOS shim image containing the original kernel and rootfs
- `bootloader/`: Directory containing the shimboot bootloader files

### Recovery Image Check (Optional)

The script checked for an optional recovery image:

```bash
check_recovery_file() {
  if [ -e "$RECOVERY_FILE" ]; then
    print_debug "✓ $RECOVERY_FILE exists - will harvest additional drivers"
    USE_RECOVERY=true
  else
    print_debug "⚠ $RECOVERY_FILE not found - skipping recovery driver harvest"
    print_debug "  Consider downloading a recovery image for better hardware support"
    USE_RECOVERY=false
  fi
}
```

**Key Note**: While the recovery image was optional, it was highly recommended as it contained additional drivers and firmware that could improve hardware compatibility.

### User Environment Validation

The script validated the user environment:

```bash
validate_user_environment() {
  print_debug "Script PID: $$"
  print_debug "User: $USER (UID: $(id -u), GID: $(id -g))"
  print_debug "Groups: $(id -Gn)"
}
```

This information was logged for debugging purposes, helping to identify permission-related issues.

## Sudo Access Setup

The script set up a mechanism to maintain sudo access throughout the build process:

```bash
# Function to keep sudo alive
setup_sudo() {
  # Start a background process to refresh sudo credentials
  sudo -v
  while true; do
    sudo -nv
    sleep 60
    kill -0 "$$" 2>/dev/null || exit
  done &
  SUDO_PID=$!
  print_debug "Sudo keepalive process started with PID: $SUDO_PID"
}

# Function to cleanup sudo process
cleanup_sudo() {
  if [ -n "$SUDO_PID" ]; then
    print_debug "Stopping sudo keepalive process (PID: $SUDO_PID)"
    kill "$SUDO_PID" 2>/dev/null || true
    wait "$SUDO_PID" 2>/dev/null || true
    SUDO_PID=""
  fi
}
```

**Key Note**: This mechanism prevented sudo timeouts during long-running operations, ensuring the build process wouldn't fail due to expired credentials.

## Logging Setup

The script set up comprehensive logging:

```bash
# Logging functions
print_info() {
  echo "[INFO] $*" | tee -a "$LOGFILE"
}

print_debug() {
  if [ "$DEBUG" = "true" ]; then
    echo "[DEBUG] $*" | tee -a "$LOGFILE"
  fi
}

print_error() {
  echo "[ERROR] $*" | tee -a "$LOGFILE" >&2
}

print_warning() {
  echo "[WARNING] $*" | tee -a "$LOGFILE" >&2
}
```

All operations were logged to `build-final-image.log`, providing a detailed record of the build process for debugging purposes.

## Error Handling Setup

The script set up comprehensive error handling:

```bash
enable_error_handling() {
  set -e
  set -o pipefail
  
  # Set up error trap with line number
  trap 'handle_error $LINENO' ERR
}

handle_error() {
  local exit_code=$?
  local line_number=$1
  print_error "Error on line $line_number: Command exited with status $exit_code"
  cleanup_all
  exit $exit_code
}
```

**Key Notes**:
- `set -e`: Exit immediately if a command exits with a non-zero status
- `set -o pipefail`: Return the exit status of the first command to fail in a pipeline
- Error trap: Captured errors with line numbers for easier debugging

## Cleanup Traps Setup

The script set up traps for graceful cleanup on exit:

```bash
setup_cleanup_traps() {
  # Set trap for normal exit
  trap 'cleanup_all' EXIT
  
  # Set trap for interruption
  trap 'print_error "Script interrupted by user"; cleanup_all; exit 130' INT
  
  # Set trap for termination
  trap 'print_error "Script terminated"; cleanup_all; exit 143' TERM
}
```

This ensured that temporary files, mount points, and loop devices were properly cleaned up even if the script was interrupted.

## Critical Considerations

1. **Systemd Version**: The build process was tightly coupled to a specific systemd version (257.6). Using a different version could cause boot failures.

2. **ChromeOS Shim Image**: The shim image must be from a compatible ChromeOS version. Mismatched versions could lead to driver incompatibility.

3. **Disk Space**: The build process required significant temporary disk space for extracting and processing components.

4. **Network Access**: The NixOS build phase required internet access to download packages and dependencies.

5. **Sudo Access**: The user needed passwordless sudo access or be prepared to enter their password multiple times.

6. **Tool Versions**: Specific versions of tools like `binwalk` and `cgpt` were required for proper operation.

7. **File Permissions**: The script needed read access to the shim image and write access to the output directory.

This phase laid the foundation for the entire build process, ensuring all prerequisites were met before proceeding with the complex operations of component harvesting and image assembly.