#!/usr/bin/env bash
set -e
set -o pipefail

# --- Helper Functions ---
print_info() {
  printf ">> \033[1;32m${1}\033[0m\n"
}

print_debug() {
  printf "   \033[0;36m${1}\033[0m\n"
}

print_error() {
  printf "!! \033[1;31m${1}\033[0m\n" >&2
}

check_sudo() {
  print_debug "Checking sudo access..."
  if ! sudo -n true 2>/dev/null; then
    echo "This script will need sudo access for some operations."
    echo "Please enter your password when prompted."
    sudo -v
  fi
  print_debug "Sudo access confirmed"
}

keep_sudo_alive() {
  print_debug "Starting sudo keepalive process..."
  while true; do
    sleep 60
    sudo -n true
  done 2>/dev/null &
  echo $! >/tmp/sudo_keepalive_$$
  print_debug "Sudo keepalive PID: $(cat /tmp/sudo_keepalive_$$)"
}

cleanup_sudo() {
  if [ -f "/tmp/sudo_keepalive_$$" ]; then
    local pid=$(cat /tmp/sudo_keepalive_$$)
    print_debug "Killing sudo keepalive process (PID: $pid)..."
    kill $pid 2>/dev/null || true
    rm -f /tmp/sudo_keepalive_$$
  fi
}

# --- Main Logic ---

if [ "$EUID" -eq 0 ]; then
  print_error "Don't run this script as root! It will escalate privileges when needed."
  exit 1
fi

print_info "Starting shimboot NixOS image build process..."
print_debug "Script PID: $$"
print_debug "User: $USER (UID: $(id -u), GID: $(id -g))"
print_debug "Groups: $(id -Gn)"

PROJECT_ROOT=$(pwd)
SHIM_FILE="$PROJECT_ROOT/data/shim.bin"
RECOVERY_FILE="$PROJECT_ROOT/data/recovery.bin"  # <-- NEW: Recovery image
KERNEL_FILE="$PROJECT_ROOT/data/kernel.bin"
BOOTLOADER_DIR="$PROJECT_ROOT/bootloader"

print_debug "Project root: $PROJECT_ROOT"
print_debug "Shim file: $SHIM_FILE"
print_debug "Recovery file: $RECOVERY_FILE"  # <-- NEW
print_debug "Kernel file: $KERNEL_FILE"
print_debug "Bootloader dir: $BOOTLOADER_DIR"

print_info "Checking prerequisites..."
for cmd in nix cgpt binwalk nixos-generate jq hexdump strings fdisk tar gunzip; do
  if command -v $cmd >/dev/null; then
    print_debug "✓ $cmd found at $(command -v $cmd)"
  else
    print_error "✗ $cmd not found"
    exit 1
  fi
done

# Check for required files
for file in "$SHIM_FILE" "$BOOTLOADER_DIR"; do
  if [ -e "$file" ]; then
    print_debug "✓ $file exists"
  else
    print_error "✗ $file not found"
    exit 1
  fi
done

# Check for recovery file (optional but recommended)
if [ -e "$RECOVERY_FILE" ]; then
  print_debug "✓ $RECOVERY_FILE exists - will harvest additional drivers"
  USE_RECOVERY=true
else
  print_debug "⚠ $RECOVERY_FILE not found - skipping recovery driver harvest"
  print_debug "  Consider downloading a recovery image for better hardware support"
  USE_RECOVERY=false
fi

check_sudo
keep_sudo_alive

TMP_DIR=$(mktemp -d)
print_info "Working directory: $TMP_DIR"
print_debug "Temp directory permissions: $(ls -ld "$TMP_DIR")"

IMAGE_LOOP=""
SHIM_LOOP=""
RECOVERY_LOOP=""  # <-- NEW
NIXOS_LOOP=""

cleanup_all() {
  print_info "Cleaning up..."
  cleanup_sudo

  for mount_point in "/tmp/new_rootfs" "/tmp/shim_bootloader" "/tmp/shim_rootfs_mount"* "/tmp/recovery_rootfs_mount"* "/tmp/nixos_source_mount"; do
    if mountpoint -q "$mount_point" 2>/dev/null; then
      print_debug "Unmounting $mount_point..."
      sudo umount "$mount_point" 2>/dev/null || true
    fi
  done

  if [ -n "$NIXOS_LOOP" ]; then
    print_debug "Detaching NixOS source loop device $NIXOS_LOOP..."
    sudo losetup -d "$NIXOS_LOOP" 2>/dev/null || true
  fi

  if [ -n "$RECOVERY_LOOP" ]; then  # <-- NEW
    print_debug "Detaching recovery loop device $RECOVERY_LOOP..."
    sudo losetup -d "$RECOVERY_LOOP" 2>/dev/null || true
  fi

  if [ -n "$SHIM_LOOP" ]; then
    print_debug "Detaching shim loop device $SHIM_LOOP..."
    sudo losetup -d "$SHIM_LOOP" 2>/dev/null || true
  fi

  if [ -n "$IMAGE_LOOP" ]; then
    print_debug "Detaching loop device $IMAGE_LOOP..."
    sudo losetup -d "$IMAGE_LOOP" 2>/dev/null || true
  fi

  if [ -n "$TMP_DIR" ] && [ -d "$TMP_DIR" ]; then
    print_debug "Removing temp directory $TMP_DIR..."
    sudo rm -rf "$TMP_DIR" 2>/dev/null || true
  fi

  print_debug "Cleanup complete"
}

trap 'cleanup_all' EXIT

# --- Step 1: The Pure Build (Raw Disk Image Method) ---
print_info "Building NixOS raw disk image..."
print_debug "Running: nixos-generate -f raw -c ./configuration.nix --system x86_64-linux"

NIXOS_IMAGE=$(nixos-generate -f raw -c ./configuration.nix --system x86_64-linux)
print_debug "nixos-generate returned: $NIXOS_IMAGE"

if [ ! -f "$NIXOS_IMAGE" ]; then
  print_error "Failed to find generated NixOS image at $NIXOS_IMAGE"
  exit 1
fi
print_info "NixOS raw image generated at $NIXOS_IMAGE"
print_debug "Image size: $(ls -lh "$NIXOS_IMAGE")"

# --- Step 2: The Impure Harvest ---
print_info "Harvesting kernel, initramfs, and modules from shim..."

# --- Step 2a: Harvest Kernel Modules from Shim ---
print_info "Mounting original ChromeOS rootfs to harvest modules..."
SHIM_LOOP=$(sudo losetup -f)
print_debug "Assigned shim loop device: $SHIM_LOOP"
sudo losetup -P "$SHIM_LOOP" "$SHIM_FILE"

# The ChromeOS rootfs is usually partition 3 (ROOT-A)
SHIM_ROOTFS_PART="${SHIM_LOOP}p3"
if [ ! -b "$SHIM_ROOTFS_PART" ]; then
  print_error "Could not find shim rootfs partition at $SHIM_ROOTFS_PART"
  exit 1
fi

SHIM_ROOTFS_MOUNT=$(mktemp -d -p /tmp -t shim_rootfs_mount.XXXXXX)
print_debug "Mounting shim rootfs partition: $SHIM_ROOTFS_PART -> $SHIM_ROOTFS_MOUNT"
sudo mount -o ro "$SHIM_ROOTFS_PART" "$SHIM_ROOTFS_MOUNT"

# Find the kernel module directory dynamically
KMOD_DIR_NAME=$(sudo ls "$SHIM_ROOTFS_MOUNT/lib/modules/" | head -n 1)
KMOD_SRC_PATH="$SHIM_ROOTFS_MOUNT/lib/modules/$KMOD_DIR_NAME"
KMOD_DEST_PATH="$TMP_DIR/kernel_modules"

print_debug "Looking for modules in $KMOD_SRC_PATH"
if [ -d "$KMOD_SRC_PATH" ]; then
  print_info "Found modules for kernel $KMOD_DIR_NAME, copying..."
  mkdir -p "$KMOD_DEST_PATH"
  sudo cp -ar "$KMOD_SRC_PATH" "$KMOD_DEST_PATH/"
  print_debug "Shim modules harvested successfully to $KMOD_DEST_PATH"
else
  print_error "Could not find kernel module directory in shim rootfs!"
  sudo ls -la "$SHIM_ROOTFS_MOUNT/lib/modules/"
  exit 1
fi

# Harvest firmware from shim
print_info "Harvesting firmware from shim..."
FIRMWARE_DEST_PATH="$TMP_DIR/firmware"
mkdir -p "$FIRMWARE_DEST_PATH"
if [ -d "$SHIM_ROOTFS_MOUNT/lib/firmware" ]; then
  sudo cp -ar "$SHIM_ROOTFS_MOUNT/lib/firmware"/* "$FIRMWARE_DEST_PATH/" 2>/dev/null || true
  print_debug "Shim firmware copied to $FIRMWARE_DEST_PATH"
fi

sudo umount "$SHIM_ROOTFS_MOUNT"
sudo losetup -d "$SHIM_LOOP"
SHIM_LOOP="" # Clear variable after use

# --- Step 2b: Harvest Additional Drivers from Recovery Image ---
if [ "$USE_RECOVERY" = true ]; then
  print_info "Mounting recovery image to harvest additional drivers..."
  RECOVERY_LOOP=$(sudo losetup -f)
  print_debug "Assigned recovery loop device: $RECOVERY_LOOP"
  sudo losetup -P "$RECOVERY_LOOP" "$RECOVERY_FILE"

  # Recovery rootfs is usually partition 3 (ROOT-A)
  RECOVERY_ROOTFS_PART="${RECOVERY_LOOP}p3"
  if [ ! -b "$RECOVERY_ROOTFS_PART" ]; then
    print_error "Could not find recovery rootfs partition at $RECOVERY_ROOTFS_PART"
    exit 1
  fi

  RECOVERY_ROOTFS_MOUNT=$(mktemp -d -p /tmp -t recovery_rootfs_mount.XXXXXX)
  print_debug "Mounting recovery rootfs partition: $RECOVERY_ROOTFS_PART -> $RECOVERY_ROOTFS_MOUNT"
  sudo mount -o ro "$RECOVERY_ROOTFS_PART" "$RECOVERY_ROOTFS_MOUNT"

  # Harvest additional firmware from recovery
  print_info "Harvesting additional firmware from recovery image..."
  if [ -d "$RECOVERY_ROOTFS_MOUNT/lib/firmware" ]; then
    sudo cp -ar "$RECOVERY_ROOTFS_MOUNT/lib/firmware"/* "$FIRMWARE_DEST_PATH/" 2>/dev/null || true
    print_debug "Recovery firmware merged into $FIRMWARE_DEST_PATH"
  fi

  # Harvest modprobe configurations
  print_info "Harvesting modprobe configurations from recovery..."
  MODPROBE_DEST_PATH="$TMP_DIR/modprobe.d"
  mkdir -p "$MODPROBE_DEST_PATH"

  if [ -d "$RECOVERY_ROOTFS_MOUNT/lib/modprobe.d" ]; then
    sudo cp -ar "$RECOVERY_ROOTFS_MOUNT/lib/modprobe.d"/* "$MODPROBE_DEST_PATH/" 2>/dev/null || true
    print_debug "Recovery lib modprobe.d copied"
  fi

  if [ -d "$RECOVERY_ROOTFS_MOUNT/etc/modprobe.d" ]; then
    sudo cp -ar "$RECOVERY_ROOTFS_MOUNT/etc/modprobe.d"/* "$MODPROBE_DEST_PATH/" 2>/dev/null || true
    print_debug "Recovery etc modprobe.d copied"
  fi

  sudo umount "$RECOVERY_ROOTFS_MOUNT"
  sudo losetup -d "$RECOVERY_LOOP"
  RECOVERY_LOOP="" # Clear variable after use
else
  print_debug "Skipping recovery image harvest - no recovery file available"
fi

# --- Step 2c: Harvest Kernel & Initramfs ---
print_info "Extracting kernel partition (KERN-A)..."
print_debug "Running: sudo cgpt show -i 2 \"$SHIM_FILE\""
cgpt_output=$(sudo cgpt show -i 2 "$SHIM_FILE")
print_debug "cgpt output:"
print_debug "$cgpt_output"

read -r part_start part_size _ < <(
  echo "$cgpt_output" | awk '$4 == "Label:" && $5 == "\"KERN-A\""'
)
print_debug "Partition start: $part_start, size: $part_size"

print_debug "Extracting kernel with dd..."
sudo dd if="$SHIM_FILE" of="$KERNEL_FILE" bs=512 skip="$part_start" count="$part_size" status=progress

print_debug "Fixing ownership of $KERNEL_FILE..."
sudo chown "$(id -u):$(id -g)" "$KERNEL_FILE"

print_info "Extracting initramfs from kernel..."
print_debug "Stage 1: Finding gzip offset..."
tmp_log_1=$(mktemp)
binwalk -y gzip -l "$tmp_log_1" "$KERNEL_FILE"
offset=$(grep '"offset"' "$tmp_log_1" | awk -F': ' '{print $2}' | sed 's/,//')
rm "$tmp_log_1"
print_debug "Gzip offset: $offset"

print_debug "Stage 1: Decompressing kernel..."
dd if="$KERNEL_FILE" bs=1 skip="$offset" | zcat >"$TMP_DIR/decompressed_kernel.bin" || true

print_debug "Stage 2: Finding XZ offset..."
tmp_log_2=$(mktemp)
binwalk -l "$tmp_log_2" "$TMP_DIR/decompressed_kernel.bin"
xz_offset=$(cat "$tmp_log_2" | jq '.[0].Analysis.file_map[] | select(.description | contains("XZ compressed data")) | .offset')
rm "$tmp_log_2"
print_debug "XZ offset: $xz_offset"

mkdir -p "$TMP_DIR/initramfs_extracted"
print_debug "Stage 2: Extracting XZ cpio archive..."
dd if="$TMP_DIR/decompressed_kernel.bin" bs=1 skip="$xz_offset" | xz -d | cpio -id -D "$TMP_DIR/initramfs_extracted" || true
print_debug "Initramfs extraction complete."

print_info "Patching initramfs with shimboot bootloader..."
original_init="$TMP_DIR/initramfs_extracted/init"
print_debug "Original init script: $original_init"
print_debug "Copying bootloader from: $BOOTLOADER_DIR"
cp -rT "$BOOTLOADER_DIR" "$TMP_DIR/initramfs_extracted/"
print_debug "Adding exec hook to init script..."
echo 'exec /bin/bootstrap.sh' >>"$original_init"
print_debug "Making bootloader scripts executable..."
find "$TMP_DIR/initramfs_extracted/bin" -type f -exec chmod +x {} \;
print_debug "Initramfs patching complete"

# --- Step 3: Mount and Extract NixOS Source ---
print_info "Mounting source NixOS image to extract rootfs..."
NIXOS_LOOP=$(sudo losetup -f)
print_debug "Assigned NixOS source loop device: $NIXOS_LOOP"
sudo losetup -P "$NIXOS_LOOP" "$NIXOS_IMAGE"

# Find the main rootfs partition in the NixOS image (usually the largest partition)
NIXOS_ROOTFS_PART="${NIXOS_LOOP}p1"
if [ ! -b "$NIXOS_ROOTFS_PART" ]; then
  # Try different partition numbers
  for part_num in 2 3 4; do
    if [ -b "${NIXOS_LOOP}p${part_num}" ]; then
      NIXOS_ROOTFS_PART="${NIXOS_LOOP}p${part_num}"
      break
    fi
  done
fi

if [ ! -b "$NIXOS_ROOTFS_PART" ]; then
  print_error "Could not find NixOS rootfs partition"
  sudo fdisk -l "$NIXOS_IMAGE"
  exit 1
fi

NIXOS_SOURCE_MOUNT="/tmp/nixos_source_mount"
sudo mkdir -p "$NIXOS_SOURCE_MOUNT"
print_debug "Mounting NixOS source partition: $NIXOS_ROOTFS_PART -> $NIXOS_SOURCE_MOUNT"
sudo mount -o ro "$NIXOS_ROOTFS_PART" "$NIXOS_SOURCE_MOUNT"

# --- Step 4: The Final Assembly ---
print_info "Assembling the final disk image..."
OUTPUT_PATH="$PROJECT_ROOT/shimboot_nixos.bin"
print_debug "Output path: $OUTPUT_PATH"

print_debug "Estimating required rootfs size from source NixOS image..."
NIXOS_USED_SIZE_KB=$(sudo du -s "$NIXOS_SOURCE_MOUNT" | cut -f1)
NIXOS_USED_SIZE_MB=$((NIXOS_USED_SIZE_KB / 1024))
ROOTFS_PART_SIZE_MB=$((NIXOS_USED_SIZE_MB * 13 / 10 + 500)) # 30% overhead + 500MB
BOOTLOADER_PART_SIZE_MB=32
TOTAL_SIZE=$((1 + 32 + BOOTLOADER_PART_SIZE_MB + ROOTFS_PART_SIZE_MB))

print_debug "NixOS used space: ${NIXOS_USED_SIZE_MB}MB"
print_debug "Final rootfs partition size: ${ROOTFS_PART_SIZE_MB}MB"
print_debug "Bootloader partition size: ${BOOTLOADER_PART_SIZE_MB}MB"
print_debug "Total image size: ${TOTAL_SIZE}MB"

print_info "Creating ${TOTAL_SIZE}MB disk image"
rm -f "$OUTPUT_PATH"
fallocate -l "${TOTAL_SIZE}M" "$OUTPUT_PATH"

print_info "Partitioning disk image"
(
  echo g
  echo n
  echo
  echo
  echo +1M
  echo n
  echo
  echo
  echo +32M
  echo n
  echo
  echo
  echo "+${BOOTLOADER_PART_SIZE_MB}M"
  echo n
  echo
  echo
  echo
  echo w
) | sudo fdisk "$OUTPUT_PATH" >/dev/null

sudo cgpt add -i 1 -t data -l "STATE" "$OUTPUT_PATH"
sudo cgpt add -i 2 -t kernel -l "kernel" -S 1 -T 5 -P 10 "$OUTPUT_PATH"
sudo cgpt add -i 3 -t rootfs -l "BOOT" "$OUTPUT_PATH"
sudo cgpt add -i 4 -t data -l "shimboot_rootfs:nixos" "$OUTPUT_PATH"

print_debug "Verifying partition table:"
sudo fdisk -l "$OUTPUT_PATH"

print_info "Creating loop device for final image"
IMAGE_LOOP=$(sudo losetup -f)
print_debug "Assigned final image loop device: $IMAGE_LOOP"
sudo losetup -P "$IMAGE_LOOP" "$OUTPUT_PATH"

print_info "Formatting partitions"
sudo mkfs.ext4 -L STATE "${IMAGE_LOOP}p1" >/dev/null
sudo dd if="$KERNEL_FILE" of="${IMAGE_LOOP}p2" bs=1M oflag=sync status=progress
sudo mkfs.ext2 -L BOOT "${IMAGE_LOOP}p3" >/dev/null
sudo mkfs.ext4 -L ROOTFS -O ^has_journal,^extent,^huge_file,^flex_bg,^metadata_csum,^64bit,^dir_nlink "${IMAGE_LOOP}p4" >/dev/null

print_info "Copying bootloader..."
BOOTLOADER_MOUNT="/tmp/shim_bootloader"
sudo mkdir -p "$BOOTLOADER_MOUNT"
sudo mount "${IMAGE_LOOP}p3" "$BOOTLOADER_MOUNT"
sudo cp -ar "$TMP_DIR/initramfs_extracted"/* "$BOOTLOADER_MOUNT/"
sudo umount "$BOOTLOADER_MOUNT"

print_info "Copying NixOS rootfs... (this may take a while)"
ROOTFS_MOUNT="/tmp/new_rootfs"
sudo mkdir -p "$ROOTFS_MOUNT"
sudo mount "${IMAGE_LOOP}p4" "$ROOTFS_MOUNT"
print_debug "Copying rootfs from source image to partition..."
sudo cp -ar "$NIXOS_SOURCE_MOUNT"/* "$ROOTFS_MOUNT/"
print_debug "Rootfs copy complete"

print_info "Creating systemd init symlink..."
# Find the patched systemd - look for our custom overridden systemd first
# Check all systemd packages and prefer the one that's not minimal and has the largest store hash (usually the patched one)
SYSTEMD_CANDIDATES=$(sudo find "${ROOTFS_MOUNT}/nix/store" -path "*/lib/systemd/systemd" -type f | grep -v minimal | sort -r)
SYSTEMD_BINARY_PATH=""

# Pick the first non-minimal systemd (should be our patched version)
if [ -n "$SYSTEMD_CANDIDATES" ]; then
  SYSTEMD_BINARY_PATH=$(echo "$SYSTEMD_CANDIDATES" | head -n 1)
fi

# Fallback to any systemd if no non-minimal found
if [ -z "$SYSTEMD_BINARY_PATH" ]; then
  SYSTEMD_BINARY_PATH=$(sudo find "${ROOTFS_MOUNT}/nix/store" -path "*/lib/systemd/systemd" -type f | head -n 1)
fi

# Final fallback to bin/systemd
if [ -z "$SYSTEMD_BINARY_PATH" ]; then
  SYSTEMD_BINARY_PATH=$(sudo find "${ROOTFS_MOUNT}/nix/store" -path "*/bin/systemd" -type f | head -n 1)
fi

if [ -n "$SYSTEMD_BINARY_PATH" ]; then
  # The path returned by find is absolute on the host. The symlink target must be absolute inside the new rootfs.
  SYMLINK_TARGET=${SYSTEMD_BINARY_PATH#"$ROOTFS_MOUNT"}

  print_debug "Found systemd binary at: $SYSTEMD_BINARY_PATH"
  print_debug "Creating symlink /init -> $SYMLINK_TARGET"
  sudo ln -sf "$SYMLINK_TARGET" "${ROOTFS_MOUNT}/init"
else
  print_error "Could not find systemd binary in the Nix store!"
  print_debug "Dumping directory listing for nix/store to debug..."
  sudo ls -l "${ROOTFS_MOUNT}/nix/store" >/tmp/nix_store_listing.txt
  print_debug "Nix store listing saved to /tmp/nix_store_listing.txt"
  exit 1
fi

print_info "Injecting harvested kernel modules into new rootfs..."
if [ -d "$TMP_DIR/kernel_modules" ]; then
  sudo mkdir -p "${ROOTFS_MOUNT}/lib/modules"
  sudo cp -ar "$TMP_DIR/kernel_modules"/* "${ROOTFS_MOUNT}/lib/modules/"
  print_debug "Modules copied to ${ROOTFS_MOUNT}/lib/modules/"

  # Decompress kernel modules if necessary - NixOS won't recognize compressed modules
  print_info "Decompressing kernel modules if needed..."
  compressed_files=$(sudo find "${ROOTFS_MOUNT}/lib/modules" -name '*.gz' 2>/dev/null || true)
  if [ -n "$compressed_files" ]; then
    print_debug "Found compressed modules, decompressing..."
    echo "$compressed_files" | sudo xargs gunzip

    # Rebuild module dependencies
    for kernel_dir in "${ROOTFS_MOUNT}/lib/modules/"*; do
      if [ -d "$kernel_dir" ]; then
        version="$(basename "$kernel_dir")"
        print_debug "Rebuilding module dependencies for kernel $version"
        sudo chroot "${ROOTFS_MOUNT}" depmod "$version" 2>/dev/null || true
      fi
    done
  fi
else
  print_error "Harvested kernel modules not found in temp directory. Skipping."
fi

# NEW: Inject firmware
print_info "Injecting harvested firmware into new rootfs..."
if [ -d "$TMP_DIR/firmware" ]; then
  sudo mkdir -p "${ROOTFS_MOUNT}/lib/firmware"
  sudo cp -ar "$TMP_DIR/firmware"/* "${ROOTFS_MOUNT}/lib/firmware/" 2>/dev/null || true
  print_debug "Firmware copied to ${ROOTFS_MOUNT}/lib/firmware/"
else
  print_debug "No harvested firmware found, skipping."
fi

# NEW: Inject modprobe configurations
if [ "$USE_RECOVERY" = true ] && [ -d "$TMP_DIR/modprobe.d" ]; then
  print_info "Injecting modprobe configurations into new rootfs..."
  sudo mkdir -p "${ROOTFS_MOUNT}/lib/modprobe.d" "${ROOTFS_MOUNT}/etc/modprobe.d"
  sudo cp -ar "$TMP_DIR/modprobe.d"/* "${ROOTFS_MOUNT}/lib/modprobe.d/" 2>/dev/null || true
  sudo cp -ar "$TMP_DIR/modprobe.d"/* "${ROOTFS_MOUNT}/etc/modprobe.d/" 2>/dev/null || true
  print_debug "Modprobe configurations copied"
fi

print_debug "Manually creating traditional symlinks..."
sudo mkdir -p "${ROOTFS_MOUNT}/sbin" "${ROOTFS_MOUNT}/usr/sbin"
sudo ln -sf /init "${ROOTFS_MOUNT}/sbin/init"
sudo ln -sf /init "${ROOTFS_MOUNT}/usr/sbin/init"

print_info "Resetting machine-id for golden image..."
if [ -f "${ROOTFS_MOUNT}/etc/machine-id" ]; then
    sudo rm -f "${ROOTFS_MOUNT}/etc/machine-id"
    print_debug "Removed existing machine-id."
fi
# Create an empty file to ensure it's generated on first boot
sudo touch "${ROOTFS_MOUNT}/etc/machine-id"
print_debug "Ensured /etc/machine-id is ready for first-boot generation."

# Unmount the source NixOS image
sudo umount "$NIXOS_SOURCE_MOUNT"
sudo losetup -d "$NIXOS_LOOP"
NIXOS_LOOP=""

sudo umount "$ROOTFS_MOUNT"

print_debug "Fixing ownership of output file..."
sudo chown "$(id -u):$(id -g)" "$OUTPUT_PATH"

print_info "All done! Your shimboot NixOS image is ready at: $OUTPUT_PATH"
print_debug "Final image size: $(ls -lh "$OUTPUT_PATH")"

if [ "$USE_RECOVERY" = true ]; then
  print_info "✓ Built with recovery image drivers - should have better hardware support"
else
  print_info "⚠ Built without recovery image - consider adding ./data/recovery.bin for better compatibility"
fi
