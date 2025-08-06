#!/usr/bin/env bash

# --- Common Utility Functions ---

print_info() {
  printf ">> \033[1;32m${1}\033[0m\n"
}

print_debug() {
  printf "   \033[0;36m${1}\033[0m\n" >&2
}

print_error() {
  printf "!! \033[1;31m${1}\033[0m\n" >&2
}

print_warning() {
  printf "⚠ \033[1;33m${1}\033[0m\n"
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

create_loop_device() {
  local image_path="$1"
  local loop_device
  
  # Try to find a free loop device
  loop_device=$(sudo losetup -f 2>/dev/null || true)
  
  if [ -z "$loop_device" ]; then
    print_error "No available loop device found"
    return 1
  fi
  
  # Set up the loop device
  if ! sudo losetup -P "$loop_device" "$image_path" 2>/dev/null; then
    print_error "Failed to set up loop device $loop_device for $image_path"
    return 1
  fi
  
  echo "$loop_device"
}

detach_loop_device() {
  local loop_device="$1"
  if [ -n "$loop_device" ]; then
    print_debug "Detaching loop device $loop_device..."
    sudo losetup -d "$loop_device" 2>/dev/null || true
  fi
}

unmount_if_mounted() {
  local mount_point="$1"
  if mountpoint -q "$mount_point" 2>/dev/null; then
    print_debug "Unmounting $mount_point..."
    sudo umount "$mount_point" 2>/dev/null || true
  fi
}

create_temp_dir() {
  local prefix="${1:-tmp}"
  mktemp -d -p /tmp -t "${prefix}.XXXXXX"
}

remove_temp_dir() {
  local temp_dir="$1"
  if [ -n "$temp_dir" ] && [ -d "$temp_dir" ]; then
    print_debug "Removing temp directory $temp_dir..."
    sudo rm -rf "$temp_dir" 2>/dev/null || true
  fi
}

log_warnings_and_errors() {
  local logfile="$1"
  if [ -f "$logfile" ]; then
    # Extract last 40 lines with 'warn' or 'error' (case-insensitive) from the log
    grep -iE 'warn|error' "$logfile" | tail -40 > build-log.txt
  fi
}