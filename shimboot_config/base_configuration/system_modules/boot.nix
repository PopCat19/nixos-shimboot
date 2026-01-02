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
{lib, ...}: {
  boot = {
    loader = {
      grub.enable = lib.mkForce false;
      systemd-boot.enable = lib.mkForce false;
      initScript.enable = lib.mkForce true;
    };
    initrd = {
      availableKernelModules = [];
      kernelModules = [];
    };
    kernelParams = [];
  };
}
