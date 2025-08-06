#!/usr/bin/env bash

# --- Main Build Script ---

# Source library modules
source "$(dirname "$0")/lib/config.sh"
source "$(dirname "$0")/lib/common.sh"
source "$(dirname "$0")/lib/prerequisites.sh"
source "$(dirname "$0")/lib/nixos-build.sh"
source "$(dirname "$0")/lib/harvest.sh"
source "$(dirname "$0")/lib/assemble.sh"
source "$(dirname "$0")/lib/cleanup.sh"

# Parse command line arguments
parse_args() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      --recovery)
        USE_RECOVERY=true
        shift
        ;;
      --systemd-version)
        SYSTEMD_VERSION_LOCK="$2"
        shift 2
        ;;
      --systemd-binary-path)
        SYSTEMD_BINARY_PATH="$2"
        shift 2
        ;;
      --no-require-patched-systemd)
        SYSTEMD_REQUIRE_PATCHED=false
        shift
        ;;
      --help|-h)
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  --recovery                    Use recovery image for additional drivers"
        echo "  --systemd-version VERSION    Lock to specific systemd version"
        echo "  --systemd-binary-path PATH    Manually specify systemd binary path"
        echo "  --no-require-patched-systemd  Don't fail if no patched systemd is found"
        echo "  --help, -h                   Show this help message"
        exit 0
        ;;
      *)
        print_error "Unknown option: $1"
        exit 1
        ;;
    esac
  done
}

# Setup logging
setup_logging() {
  # Create log file
  LOGFILE="build-final-image.log"
  exec > >(tee -a "$LOGFILE")
  exec 2>&1
}

# Setup cleanup trap
setup_cleanup() {
  # Set trap to cleanup on exit
  trap cleanup EXIT
}

# Check prerequisites
check_prerequisites() {
  print_info "Checking prerequisites..."
  
  # Check required commands
  for cmd in $REQUIRED_COMMANDS; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      print_error "Required command '$cmd' not found"
      exit 1
    fi
    print_debug "✓ $cmd found at $(command -v "$cmd")"
  done
  
  # Check required files
  for file in $REQUIRED_FILES; do
    if [ ! -e "$file" ]; then
      print_error "Required file '$file' not found"
      exit 1
    fi
    print_debug "✓ $file exists"
  done
  
  # Check WiFi credentials
  if [ -f "$WIFI_CREDENTIALS_FILE" ]; then
    print_info "✓ WiFi credentials file found at $WIFI_CREDENTIALS_FILE"
    print_debug "WiFi autoconnect will be configured in the built image"
    
    # Validate JSON format if jq is available
    if command -v jq >/dev/null 2>&1; then
      if jq empty "$WIFI_CREDENTIALS_FILE" 2>/dev/null; then
        print_debug "✓ WiFi credentials JSON is valid"
        
        # Extract SSID for display (without showing PSK)
        WIFI_SSID=$(jq -r '.wifi.ssid' "$WIFI_CREDENTIALS_FILE" 2>/dev/null)
        WIFI_SECURITY=$(jq -r '.wifi.security' "$WIFI_CREDENTIALS_FILE" 2>/dev/null)
        if [ -n "$WIFI_SSID" ] && [ "$WIFI_SSID" != "null" ]; then
          print_info "  WiFi Network: $WIFI_SSID (Security: $WIFI_SECURITY)"
        fi
      else
        print_error "✗ WiFi credentials file contains invalid JSON"
        print_error "  Please check the format of $WIFI_CREDENTIALS_FILE"
        print_error "  Use $WIFI_CREDENTIALS_EXAMPLE as a reference"
        exit 1
      fi
    fi
  else
    print_warning "⚠ WiFi credentials file not found at $WIFI_CREDENTIALS_FILE"
    print_info "  WiFi autoconnect will not be configured"
    print_info "  To enable WiFi autoconnect:"
    print_info "  1. Copy $WIFI_CREDENTIALS_EXAMPLE to $WIFI_CREDENTIALS_FILE"
    print_info "  2. Edit $WIFI_CREDENTIALS_FILE with your WiFi credentials"
    print_info "  3. Run the build script again"
  fi
  
  # Check if recovery file exists if using recovery
  if [ "$USE_RECOVERY" = true ]; then
    if [ ! -e "$RECOVERY_FILE" ]; then
      print_error "Recovery file '$RECOVERY_FILE' not found"
      exit 1
    fi
    print_debug "✓ $RECOVERY_FILE exists - will harvest additional drivers"
  fi
  
  # Check sudo access
  print_debug "Checking sudo access..."
  if ! sudo -v; then
    print_error "This script requires sudo access"
    exit 1
  fi
  print_debug "Sudo access confirmed"
}

# Harvest firmware from shim
harvest_shim_firmware() {
  print_info "Harvesting firmware from shim..."
  
  # Create firmware directory
  mkdir -p "$TMP_DIR/firmware"
  
  # Copy firmware from shim rootfs
  if [ -d "$SHIM_ROOTFS_MOUNT/lib/firmware" ]; then
    cp -r "$SHIM_ROOTFS_MOUNT/lib/firmware"/* "$TMP_DIR/firmware/" 2>/dev/null || true
    print_debug "Shim firmware copied to $TMP_DIR/firmware"
  else
    print_debug "No firmware directory found in shim rootfs"
  fi
}

# Extract kernel partition
extract_kernel_partition() {
  print_info "Extracting kernel partition (KERN-A)..."
  
  # Get kernel partition info
  print_debug "Running: sudo cgpt show -i 2 \"$SHIM_FILE\""
  local cgpt_output
  cgpt_output=$(sudo cgpt show -i 2 "$SHIM_FILE")
  print_debug "cgpt output:"
  print_debug "$cgpt_output"
  
  # Extract partition start and size
  local part_start part_size
  part_start=$(echo "$cgpt_output" | awk '/start/ {print $2}')
  part_size=$(echo "$cgpt_output" | awk '/size/ {print $4}')
  
  print_debug "Partition start: $part_start, size: $part_size"
  
  # Extract kernel with dd
  print_debug "Extracting kernel with dd..."
  sudo dd if="$SHIM_FILE" of="$KERNEL_FILE" bs=512 skip="$part_start" count="$part_size" status=progress
  
  # Fix ownership
  sudo chown "$(id -u):$(id -g)" "$KERNEL_FILE"
  print_debug "Fixing ownership of $KERNEL_FILE..."
}

# Extract initramfs from kernel
extract_initramfs() {
  print_info "Extracting initramfs from kernel..."
  
  # Stage 1: Find gzip offset
  print_debug "Stage 1: Finding gzip offset..."
  local gzip_offset
  gzip_offset=$(binwalk "$KERNEL_FILE" | grep "gzip compressed data" | head -1 | awk '{print $1}')
  print_debug "Gzip offset: $gzip_offset"
  
  # Stage 1: Decompress kernel
  print_debug "Stage 1: Decompressing kernel..."
  dd if="$KERNEL_FILE" bs=1 skip="$gzip_offset" 2>/dev/null | gunzip > "$TMP_DIR/decompressed_kernel.bin"
  
  # Stage 2: Find XZ offset
  print_debug "Stage 2: Finding XZ offset..."
  local xz_offset
  xz_offset=$(binwalk "$TMP_DIR/decompressed_kernel.bin" | grep "XZ compressed data" | head -1 | awk '{print $1}')
  print_debug "XZ offset: $xz_offset"
  
  # Stage 2: Extract XZ cpio archive
  print_debug "Stage 2: Extracting XZ cpio archive..."
  mkdir -p "$TMP_DIR/initramfs_extracted"
  dd if="$TMP_DIR/decompressed_kernel.bin" bs=1 skip="$xz_offset" 2>/dev/null | xz -dc | cpio -idm -D "$TMP_DIR/initramfs_extracted" 2>/dev/null || true
  print_debug "Initramfs extraction complete."
}

# Patch initramfs with shimboot bootloader
patch_initramfs() {
  print_info "Patching initramfs with shimboot bootloader..."
  
  local init_script="$TMP_DIR/initramfs_extracted/init"
  print_debug "Original init script: $init_script"
  
  # Copy bootloader from: /home/popcat19/nixos-shimboot/bootloader
  print_debug "Copying bootloader from: $BOOTLOADER_DIR"
  cp -r "$BOOTLOADER_DIR"/* "$TMP_DIR/initramfs_extracted/"
  
  # Add exec hook to init script
  if [ -f "$init_script" ]; then
    # Create backup
    cp "$init_script" "$init_script.bak"
    
    # Add exec hook at the beginning
    {
      echo "#!/bin/sh"
      echo "# Shimboot init hook"
      echo "exec /bootloader/init \"\$@\""
      echo ""
      cat "$init_script.bak"
    } > "$init_script"
    
    # Remove backup
    rm "$init_script.bak"
  fi
  
  # Make bootloader scripts executable
  chmod +x "$TMP_DIR/initramfs_extracted/bootloader/init"
  chmod +x "$TMP_DIR/initramfs_extracted/bootloader/hooks/exec"
  
  print_debug "Initramfs patching complete"
}

# Mount and harvest modules from shim
harvest_shim_modules() {
  print_info "Mounting original ChromeOS rootfs to harvest modules..."
  
  # Create mount point
  SHIM_ROOTFS_MOUNT=$(mktemp -d)
  print_debug "Mounting shim rootfs partition: /dev/loop0p3 -> $SHIM_ROOTFS_MOUNT"
  
  # Assign loop device and mount
  local shim_loop
  shim_loop=$(create_loop_device "$SHIM_FILE")
  print_debug "Assigned shim loop device: $shim_loop"
  
  sudo mount "${shim_loop}p3" "$SHIM_ROOTFS_MOUNT"
  
  # Find modules directory
  local modules_dir
  modules_dir=$(find "$SHIM_ROOTFS_MOUNT/lib/modules" -maxdepth 1 -type d | head -1)
  
  if [ -n "$modules_dir" ]; then
    local kernel_version
    kernel_version=$(basename "$modules_dir")
    print_debug "Found modules for kernel $kernel_version, copying..."
    
    # Create destination directory
    mkdir -p "$TMP_DIR/kernel_modules"
    
    # Copy modules
    cp -r "$modules_dir" "$TMP_DIR/kernel_modules/"
    print_debug "Shim modules harvested successfully to $TMP_DIR/kernel_modules"
  else
    print_debug "No modules directory found in shim rootfs"
  fi
  
  # Unmount and cleanup
  unmount_if_mounted "$SHIM_ROOTFS_MOUNT"
  remove_temp_dir "$SHIM_ROOTFS_MOUNT"
  detach_loop_device "$shim_loop"
}

# Harvest recovery components
harvest_recovery_components() {
  print_info "Mounting recovery image to harvest additional drivers..."
  
  # Create mount point
  RECOVERY_ROOTFS_MOUNT=$(mktemp -d)
  print_debug "Mounting recovery rootfs partition: /dev/loop0p3 -> $RECOVERY_ROOTFS_MOUNT"
  
  # Assign loop device and mount
  local recovery_loop
  recovery_loop=$(create_loop_device "$RECOVERY_FILE")
  print_debug "Assigned recovery loop device: $recovery_loop"
  
  sudo mount "${recovery_loop}p3" "$RECOVERY_ROOTFS_MOUNT"
  
  # Harvest additional firmware
  if [ -d "$RECOVERY_ROOTFS_MOUNT/lib/firmware" ]; then
    print_info "Harvesting additional firmware from recovery image..."
    cp -r "$RECOVERY_ROOTFS_MOUNT/lib/firmware"/* "$TMP_DIR/firmware/" 2>/dev/null || true
    print_debug "Recovery firmware merged into $TMP_DIR/firmware"
  fi
  
  # Harvest modprobe configurations
  print_info "Harvesting modprobe configurations from recovery..."
  mkdir -p "$TMP_DIR/modprobe.d"
  
  if [ -d "$RECOVERY_ROOTFS_MOUNT/lib/modprobe.d" ]; then
    cp -r "$RECOVERY_ROOTFS_MOUNT/lib/modprobe.d"/* "$TMP_DIR/modprobe.d/" 2>/dev/null || true
    print_debug "Recovery lib modprobe.d copied"
  fi
  
  if [ -d "$RECOVERY_ROOTFS_MOUNT/etc/modprobe.d" ]; then
    cp -r "$RECOVERY_ROOTFS_MOUNT/etc/modprobe.d"/* "$TMP_DIR/modprobe.d/" 2>/dev/null || true
    print_debug "Recovery etc modprobe.d copied"
  fi
  
  # Unmount and cleanup
  unmount_if_mounted "$RECOVERY_ROOTFS_MOUNT"
  remove_temp_dir "$RECOVERY_ROOTFS_MOUNT"
  detach_loop_device "$recovery_loop"
}

# Harvest components
harvest_components() {
  print_info "Harvesting kernel, initramfs, and modules from shim..."
  
  # Create temporary directory
  TMP_DIR=$(mktemp -d)
  print_debug "Working directory: $TMP_DIR"
  print_debug "Temp directory permissions: $(ls -ld "$TMP_DIR")"
  
  # Extract kernel partition
  extract_kernel_partition
  
  # Extract initramfs
  extract_initramfs
  
  # Patch initramfs
  patch_initramfs
  
  # Mount and harvest modules from shim
  harvest_shim_modules
  
  # Mount and harvest firmware from shim
  harvest_shim_firmware
  
  # Mount and harvest from recovery if enabled
  if [ "$USE_RECOVERY" = true ]; then
    harvest_recovery_components
  fi
}

# Main build process
main() {
  # Initialize configuration first
  init_config
  
  # Parse command line arguments (this will override config values)
  parse_args "$@"
  
  # Print banner and configuration
  print_info "Starting shimboot NixOS image build process..."
  print_config
  
  # Setup logging and cleanup
  setup_logging
  setup_cleanup
  
  # Check prerequisites
  check_prerequisites
  
  # Step 1: Build NixOS raw disk image
  print_info "Step 1: Building NixOS raw disk image..."
  print_info "  This may take 10-30 minutes on first run as it downloads and builds all packages..."
  print_info "  Building with verbose output to show progress..."
  echo ""
  
  # Build with verbose output
  print_debug "Running: nixos-generate -f raw -c ./configuration.nix --system x86_64-linux --show-trace"
  nixos_image=$(nixos-generate -f raw -c ./configuration.nix --system x86_64-linux --show-trace 2>&1 | tee /dev/tty | grep -o '/nix/store/[^[:space:]]*\.img' | tail -1)
  echo ""
  
  if [ -z "$nixos_image" ]; then
    print_error "Failed to extract NixOS image path from nixos-generate output"
    print_error "Check the output above for error messages"
    exit 1
  fi
  print_info "NixOS raw image generated at $nixos_image"
  print_debug "Image size: $(ls -lh "$nixos_image")"
  
  # Step 2: Harvest kernel, initramfs, and modules from shim
  print_info "Step 2: Harvesting kernel, initramfs, and modules from shim..."
  harvest_components
  
  # Step 3: Mount NixOS image
  print_info "Step 3: Mounting NixOS image..."
  mount_nixos_image "$nixos_image"
  
  # Step 4: Assemble final disk image
  print_info "Step 4: Assembling final disk image..."
  assemble_final_image
  
  print_info "Build completed successfully!"
}

# Cleanup function
cleanup() {
  print_info "Cleaning up..."
  
  # Kill sudo keepalive process if running
  if [ -n "$SUDO_KEEPALIVE_PID" ]; then
    print_debug "Killing sudo keepalive process (PID: $SUDO_KEEPALIVE_PID)..."
    kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
  fi
  
  # Unmount any mounted filesystems
  unmount_if_mounted "$ROOTFS_MOUNT"
  unmount_if_mounted "$NIXOS_SOURCE_MOUNT"
  unmount_if_mounted "$BOOTLOADER_MOUNT"
  unmount_if_mounted "$SHIM_ROOTFS_MOUNT"
  unmount_if_mounted "$RECOVERY_ROOTFS_MOUNT"
  
  # Detach any loop devices
  if [ -n "$IMAGE_LOOP" ]; then
    detach_loop_device "$IMAGE_LOOP"
  fi
  if [ -n "$NIXOS_LOOP" ]; then
    detach_loop_device "$NIXOS_LOOP"
  fi
  if [ -n "$SHIM_LOOP" ]; then
    detach_loop_device "$SHIM_LOOP"
  fi
  if [ -n "$RECOVERY_LOOP" ]; then
    detach_loop_device "$RECOVERY_LOOP"
  fi
  
  # Remove temporary directories
  if [ -n "$TMP_DIR" ] && [ -d "$TMP_DIR" ]; then
    print_debug "Removing temp directory $TMP_DIR..."
    rm -rf "$TMP_DIR"
  fi
  
  print_debug "Cleanup complete."
}

# Run main function with all arguments
main "$@"
