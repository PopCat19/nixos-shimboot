#!/bin/busybox sh
# Copyright 2015 The Chromium OS Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#
# To bootstrap the factory installer on rootfs. This file must be executed as
# PID=1 (exec).
# Note that this script uses the busybox shell (not bash, not dash).
set -x

. /usr/sbin/factory_tty.sh

# USB card partition and mount point.
USB_MNT=/usb
REAL_USB_DEV=

NEWROOT_MNT=/newroot

LOG_DEV=
LOG_DIR=/log
LOG_FILE=${LOG_DIR}/factory_initramfs.log

# Size of the root ramdisk.
TMPFS_SIZE=512M

# Special file systems required in addition to the root file system.
BASE_MOUNTS="/sys /proc /dev"

# To be updated to keep logging after move_mounts.
TAIL_PID=

# Print message on both main TTY and log file.
info() {
  echo "$@" | tee -a "${TTY}" "${LOG_FILE}"
}

is_cros_debug() {
  grep -qw cros_debug /proc/cmdline 2>/dev/null
}

invoke_terminal() {
  local tty="$1"
  local title="$2"
  shift
  shift
  # Copied from factory_installer/factory_shim_service.sh.
  echo "${title}" >>${tty}
  setsid sh -c "exec script -afqc '$*' /dev/null <${tty} >>${tty} 2>&1 &"
}

enable_debug_console() {
  local tty="$1"
  if ! is_cros_debug; then
    info "To debug, add [cros_debug] to your kernel command line."
  elif [ "${tty}" = /dev/null ] || ! tty_is_valid "${tty}"; then
    # User probably can't see this, but we don't have better way.
    info "Please set a valid [console=XXX] in kernel command line."
  else
    info -e '\033[1;33m[cros_debug] enabled on '${tty}'.\033[m'
    invoke_terminal "${tty}" "[Bootstrap Debug Console]" "/bin/busybox sh"
  fi
}

on_error() {
  trap - EXIT
  info -e '\033[1;31m'
  info "ERROR: Factory installation aborted."
  save_log_files
  enable_debug_console "${TTY}"
  sleep 1d
  exit 1
}

# Look for a device with our GPT ID.
wait_for_gpt_root() {
  [ -z "$KERN_ARG_KERN_GUID" ] && return 1
  info -n "Looking for rootfs using kern_guid [${KERN_ARG_KERN_GUID}]... "
  local try kern_dev kern_num
  local root_dev root_num
  for try in $(seq 20); do
    info -n ". "
    # crbug.com/463414: when the cgpt supports MTD (cgpt.bin), redirecting its
    # output will get duplicated data.
    kern_dev="$(cgpt find -1 -u $KERN_ARG_KERN_GUID 2>/dev/null | uniq)"
    kern_num=${kern_dev##[/a-z]*[/a-z]}
    # rootfs partition is always in kernel partition + 1.
    root_num=$(( kern_num + 1 ))
    root_dev="${kern_dev%${kern_num}}${root_num}"
    if [ -b "$root_dev" ]; then
      USB_DEV="$root_dev"
      info "Found ${USB_DEV}"
      return 0
    fi
    sleep 1
  done
  info "Failed waiting for device with correct kern_guid."
  return 1
}

# Attempt to find the root defined in the signed factory shim
# kernel we're booted into to. Exports REAL_USB_DEV if there
# is a root partition that may be used - on succes or failure.
find_official_root() {
  info -n "Checking for an official root... "

  # Check for a kernel selected root device or one in a well known location.
  wait_for_gpt_root || return 1

  # Now see if it has a Chrome OS rootfs partition.
  cgpt find -t rootfs "$(strip_partition "$USB_DEV")" || return 1
  REAL_USB_DEV="$USB_DEV"

  # USB_DEV points to the rootfs partition of removable media. And its value
  # can be one of /dev/sda3 (arm), /dev/sdb3 (x86, arm) and /dev/mmcblk1p3
  # (arm). Get stateful partition by replacing partition number with "1".
  LOG_DEV="${USB_DEV%[0-9]*}"1  # Default to stateful.

  mount_usb
}

mount_usb() {
  info -n "Mounting usb... "
  for try in $(seq 20); do
    info -n ". "
    if mount -n -o ro "$USB_DEV" "$USB_MNT"; then
      info "OK."
      return 0
    fi
    sleep 1
  done
  info "Failed to mount usb!"
  return 1
}

unmount_usb() {
  info "Unmounting ${USB_MNT}..."
  umount -n "${USB_MNT}"
  info ""
  info "$REAL_USB_DEV can now be safely removed."
  info ""
}

strip_partition() {
  local dev="${1%[0-9]*}"
  # handle mmcblk0p case as well
  echo "${dev%p*}"
}

# Saves log files stored in LOG_DIR in addition to demsg to the device specified
# (/ of stateful mount if none specified).
save_log_files() {
  # The recovery stateful is usually too small for ext3.
  # TODO(wad) We could also just write the data raw if needed.
  #           Should this also try to save
  local log_dev="${1:-$LOG_DEV}"
  [ -z "$log_dev" ] && return 0

  info "Dumping dmesg to $LOG_DIR"
  dmesg >"$LOG_DIR"/dmesg

  local err=0
  local save_mnt=/save_mnt
  local save_dir_name="factory_shim_logs"
  local save_dir="${save_mnt}/${save_dir_name}"

  info "Saving log files from: $LOG_DIR -> $log_dev $(basename ${save_dir})"
  mkdir -p "${save_mnt}"
  mount -n -o sync,rw "${log_dev}" "${save_mnt}" || err=$?
  [ ${err} -ne 0 ] || rm -rf "${save_dir}" || err=$?
  [ ${err} -ne 0 ] || cp -r "${LOG_DIR}" "${save_dir}" || err=$?
  # Attempt umount, even if there was an error to avoid leaking the mount.
  umount -n "${save_mnt}" || err=1

  if [ ${err} -eq 0 ] ; then
    info "Successfully saved the log file."
    info ""
    info "Please remove the USB media, insert into a Linux machine,"
    info "mount the first partition, and find the logs in directory:"
    info "  ${save_dir_name}"
  else
    info "Failures seen trying to save log file."
  fi
}

stop_log_file() {
  # Drop logging
  exec >"${TTY}" 2>&1
  [ -n "$TAIL_PID" ] && kill $TAIL_PID
}

# Extract and export kernel arguments
export_args() {
  # We trust our kernel command line explicitly.
  local arg=
  local key=
  local val=
  local acceptable_set='[A-Za-z0-9]_'
  info "Exporting kernel arguments..."
  for arg in "$@"; do
    key=$(echo "${arg%%=*}" | tr 'a-z' 'A-Z' | \
                   tr -dc "$acceptable_set" '_')
    val="${arg#*=}"
    export "KERN_ARG_$key"="$val"
    info -n " KERN_ARG_$key=$val,"
  done
  info ""
}

mount_tmpfs() {
  info "Mounting tmpfs..."
  mount -n -t tmpfs tmpfs "$NEWROOT_MNT" -o "size=$TMPFS_SIZE"
}

copy_contents() {
  info "Copying contents of USB device to tmpfs... "
  tar -cf - -C "${USB_MNT}" . | pv -f 2>"${TTY}" | tar -xf - -C "${NEWROOT_MNT}"
}

patch_new_root() {
  # Create an early debug terminal if available.
  if is_cros_debug && [ -n "${DEBUG_TTY}" ]; then
    info "Adding debug console service..."
    file="${NEWROOT_MNT}/etc/init/debug_console.conf"
    echo "# Generated by factory shim.
      start on startup
      console output
      respawn
      pre-start exec printf '\n[Debug Console]\n' >${DEBUG_TTY}
      exec script -afqc '/bin/bash' /dev/null" >"${file}"
    if [ "${DEBUG_TTY}" != /dev/console ]; then
      rm -f /dev/console
      ln -s "${DEBUG_TTY}" /dev/console
    fi
  fi

  local bootstrap="${NEWROOT_MNT}/usr/sbin/factory_bootstrap.sh"
  local flag="/tmp/bootstrap.failed"
  if [ -x "${bootstrap}" ]; then
    rm -f "${flag}"
    info "Running ${bootstrap}..."
    # Return code of "a|b" is will be b instead of a, so we have to touch a flag
    # file to check results.
    ("${bootstrap}" "${NEWROOT_MNT}" "${REAL_USB_DEV}" || touch "${flag}") \
      | tee -a "${TTY}" "${LOG_FILE}"
    if [ -e "${flag}" ]; then
      return 1
    fi
  fi
}

move_mounts() {
  info "Moving $BASE_MOUNTS to $NEWROOT_MNT"
  for mnt in $BASE_MOUNTS; do
    # $mnt is a full path (leading '/'), so no '/' joiner
    mkdir -p "$NEWROOT_MNT$mnt"
    mount -n -o move "$mnt" "$NEWROOT_MNT$mnt"
  done

  # Adjust /dev files.
  TTY="${NEWROOT_MNT}${TTY}"
  LOG_TTY="${NEWROOT_MNT}${LOG_TTY}"
  [ -z "${LOG_DEV}" ] || LOG_DEV="${NEWROOT_MNT}${LOG_DEV}"

  # Make a copy of bootstrap log into new root.
  mkdir -p "${NEWROOT_MNT}${LOG_DIR}"
  cp -f "${LOG_FILE}" "${NEWROOT_MNT}${LOG_FILE}"
  info "Done."
}

use_new_root() {
  move_mounts

  # Chroot into newroot, erase the contents of the old /, and exec real init.
  info "About to switch root... Check VT2/3/4 if you stuck for a long time."
  stop_log_file

  # If you have problem getting console after switch_root, try to debug by:
  #  1. Try a simple shell.
  #     exec <"${TTY}" >"${TTY}" 2>&1
  #     exec switch_root "${NEWROOT_MNT}" /bin/sh
  #  2. Try to invoke factory installer directly
  #     exec switch_root "${NEWROOT_MNT}" /usr/sbin/factory_shim_service.sh

  # -v prints upstart info in kmsg (available in INFO_TTY).
  exec switch_root "${NEWROOT_MNT}" /sbin/init -v --default-console output
}

main() {
  # Setup environment.
  tty_init
  if [ -z "${LOG_TTY}" ]; then
    LOG_TTY=/dev/null
  fi

  mkdir -p "${USB_MNT}" "${LOG_DIR}" "${NEWROOT_MNT}"

  exec >"${LOG_FILE}" 2>&1
  info "...:::||| Bootstrapping ChromeOS Factory Shim |||:::..."
  info "TTY: ${TTY}, LOG: ${LOG_TTY}, INFO: ${INFO_TTY}, DEBUG: ${DEBUG_TTY}"

  # Send all verbose output to debug TTY.
  (tail -f "${LOG_FILE}" >"${LOG_TTY}") &
  TAIL_PID="$!"

  # Export the kernel command line as a parsed blob prepending KERN_ARG_ to each
  # argument.
  export_args $(cat /proc/cmdline | sed -e 's/"[^"]*"/DROPPED/g')

  if [ -n "${INFO_TTY}" -a -e /dev/kmsg ]; then
    info "Kernel messages available in ${INFO_TTY}."
    cat /dev/kmsg >>"${INFO_TTY}" &
  fi

  # DEBUG_TTY may be not available, but we don't have better choices on headless
  # devices.
  enable_debug_console "${DEBUG_TTY}"

  find_official_root

  info "Bootstrapping factory shim."
  # Copy rootfs contents to tmpfs, then unmount USB device.
  mount_tmpfs
  copy_contents

  # Apply all patches for bootstrap into new rootfs.
  patch_new_root

  # USB device is unmounted, we can remove it now.
  unmount_usb

  # Kill all running terminals. Comment this line if you need to keep debug
  # console open for debugging.
  killall less script || true

  # Switch to the new root.
  use_new_root

  # Should never reach here.
  return 1
}

trap on_error EXIT
set -e
main "$@"
