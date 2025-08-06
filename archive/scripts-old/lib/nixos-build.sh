#!/usr/bin/env bash

# --- NixOS Image Building Functions ---

# Build NixOS raw disk image
build_nixos_image() {
  print_info "Building NixOS raw disk image..."
  print_debug "Running: nixos-generate -f raw -c ./configuration.nix --system x86_64-linux"
  
  # Build the image and capture the output
  local nixos_image
  nixos_image=$(nixos-generate -f raw -c ./configuration.nix --system x86_64-linux 2>&1 | tail -1)
  
  if [ -z "$nixos_image" ]; then
    print_error "nixos-generate did not return an image path"
    exit 1
  fi
  
  # Check if the image file exists
  if [ ! -f "$nixos_image" ]; then
    print_error "Failed to find generated NixOS image at $nixos_image"
    exit 1
  fi
  
  print_info "NixOS raw image generated at $nixos_image"
  print_debug "Image size: $(ls -lh "$nixos_image")"
  
  # Return the image path
  echo "$nixos_image"
}

# Mount NixOS image and extract rootfs
mount_nixos_image() {
  local nixos_image="$1"
  
  print_info "Mounting source NixOS image to extract rootfs..."
  print_debug "NixOS image path: $nixos_image"
  
  # Check if the image file exists
  if [ ! -f "$nixos_image" ]; then
    print_error "NixOS image file not found: $nixos_image"
    exit 1
  fi
  
  # Try to create loop device with retry mechanism
  local retry_count=0
  local max_retries=3
  while [ $retry_count -lt $max_retries ]; do
    NIXOS_LOOP=$(create_loop_device "$nixos_image")
    if [ -n "$NIXOS_LOOP" ]; then
      break
    fi
    print_debug "Retry $((retry_count + 1)) for creating loop device..."
    sleep 1
    retry_count=$((retry_count + 1))
  done
  
  if [ -z "$NIXOS_LOOP" ]; then
    print_error "Failed to create loop device for NixOS image"
    exit 1
  fi
  
  print_debug "Assigned NixOS source loop device: $NIXOS_LOOP"
  
  # Find the main rootfs partition in the NixOS image (usually the largest partition)
  local nixos_rootfs_part="${NIXOS_LOOP}p1"
  if [ ! -b "$nixos_rootfs_part" ]; then
    # Try different partition numbers
    for part_num in 2 3 4; do
      if [ -b "${NIXOS_LOOP}p${part_num}" ]; then
        nixos_rootfs_part="${NIXOS_LOOP}p${part_num}"
        break
      fi
    done
  fi
  
  if [ ! -b "$nixos_rootfs_part" ]; then
    print_error "Could not find NixOS rootfs partition"
    sudo fdisk -l "$nixos_image"
    exit 1
  fi
  
  sudo mkdir -p "$NIXOS_SOURCE_MOUNT"
  print_debug "Mounting NixOS source partition: $nixos_rootfs_part -> $NIXOS_SOURCE_MOUNT"
  sudo mount -o ro "$nixos_rootfs_part" "$NIXOS_SOURCE_MOUNT"
}

# Calculate required image size based on NixOS image
calculate_image_size() {
  print_debug "Estimating required rootfs size from source NixOS image..."
  
  local nixos_used_size_kb
  nixos_used_size_kb=$(sudo du -s "$NIXOS_SOURCE_MOUNT" | cut -f1)
  
  local nixos_used_size_mb=$((nixos_used_size_kb / 1024))
  local rootfs_part_size_mb=$((nixos_used_size_mb * 13 / 10 + 500)) # 30% overhead + 500MB
  local total_size=$((STATE_PART_SIZE_MB + KERNEL_PART_SIZE_MB + BOOTLOADER_PART_SIZE_MB + rootfs_part_size_mb))
  
  print_debug "NixOS used space: ${nixos_used_size_mb}MB"
  print_debug "Final rootfs partition size: ${rootfs_part_size_mb}MB"
  print_debug "Bootloader partition size: ${BOOTLOADER_PART_SIZE_MB}MB"
  print_debug "Total image size: ${total_size}MB"
  
  # Only output the total size value
  echo "$total_size"
}

# Unmount NixOS image
unmount_nixos_image() {
  if [ -d "$NIXOS_SOURCE_MOUNT" ]; then
    unmount_if_mounted "$NIXOS_SOURCE_MOUNT"
  fi
  detach_loop_device "$NIXOS_LOOP"
  NIXOS_LOOP=""
}