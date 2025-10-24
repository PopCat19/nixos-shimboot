# Boot Configuration Module
#
# Purpose: Configure bootloader and kernel settings for shimboot
# Dependencies: systemd-boot, kernel modules
# Related: hardware.nix, filesystem.nix
#
# This module:
# - Disables standard bootloaders in favor of shimboot init script
# - Configures kernel modules for ChromeOS hardware compatibility
# - Sets up initramfs with necessary modules

{
  config,
  pkgs,
  lib,
  ...
}: {
  boot = {
    loader = {
      grub.enable = false;
      systemd-boot.enable = false;
      initScript.enable = true;
    };
    initrd = {
      availableKernelModules = [];
      kernelModules = [];
    };
    kernelParams = [];
  };
}
