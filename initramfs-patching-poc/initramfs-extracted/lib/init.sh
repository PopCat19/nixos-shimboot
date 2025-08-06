# Copyright 2015 The Chromium OS Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# Common runtime library used by /init scripts.  All "exported" utility
# functions should start with "init_".

# Sanity check the date (crosbug.com/13200)
init_check_clock() {
  if [ $(date +%Y) -lt 1970 ]; then
    date 010200001970.00
  fi
}

# Set up all the common system mount points.
init_mounts() {
  mount -n -t proc -o nodev,noexec,nosuid proc /proc
  mount -n -t sysfs -o nodev,noexec,nosuid sysfs /sys

  mount -t devtmpfs -o mode=0755,nosuid devtmpfs /dev
  ln -sf /proc/self/fd /dev/fd || :
  ln -sf fd/0 /dev/stdin || :
  ln -sf fd/1 /dev/stdout || :
  ln -sf fd/2 /dev/stderr || :

  # Normally we would mount /run as a tmpfs, but since / is already a tmpfs
  # in an initramfs env, don't bother creating another mount on top of it.

  mkdir -p /dev/pts
  mount -n -t devpts -o noexec,nosuid devpts /dev/pts || :

  mount -n -t debugfs debugfs /sys/kernel/debug
}

# Run all the common init functions.
initialize() {
  init_check_clock
  init_mounts
}
