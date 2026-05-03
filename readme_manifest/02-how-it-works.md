
## How It Works

Based on [ading2210/shimboot](https://github.com/ading2210/shimboot), which first applied the RMA shim rootfs vulnerability (originally exploited by MercuryWorkshop's SH1MMER) to boot Linux distributions.

ChromeOS RMA shims are bootable recovery images that run even on enterprise-enrolled devices. The shim's root filesystem is unverified, allowing it to be replaced with a Linux rootfs.

The ChromeOS kernel fails systemd's API filesystem mounts. Systemd resolves mount targets through `/proc/self/fd/`, which the ChromeOS kernel handles differently. The patch replaces this with a direct `mount()` call ([d27b392/patches/systemd-mountpoint-util-chromeos.patch](https://github.com/PopCat19/nixos-shimboot/blob/d27b392/patches/systemd-mountpoint-util-chromeos.patch)).

The patch is needed whenever systemd components run in the boot chain — as the init system, or as supporting daemons like udev. Inits that don't pull systemd components, like Alpine's OpenRC, work without the patch.

Artix's OpenRC pulls `udev` and related packages split from systemd source, so the patch is still needed there ([shimboot#405 (comment)](https://github.com/ading2210/shimboot/issues/405#issuecomment-4234987149)).

Distribution-specific integration is also needed. Upstream shimboot supports Debian; this project adds NixOS.

```
ChromeOS firmware → RMA shim (patched initramfs) → bootloader → NixOS
```

A custom bootloader inside the patched initramfs handles the transition.

It mounts the NixOS rootfs, binds vendor firmware and kernel modules, then `pivot_root` into NixOS.

All of this fits on a USB drive. Reboot without it and the device returns to ChromeOS untouched.


