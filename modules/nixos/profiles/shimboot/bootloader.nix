# Shimboot Bootloader Configuration
#
# Purpose: Configure shimboot-specific bootloader settings
# Dependencies: bootloader/ directory
# Related: modules/nixos/core, modules/nixos/hardware
#
# This module:
# - Integrates with shimboot bootloader
# - Configures kernel parameters for ChromeOS
# - Sets up initramfs for shimboot
{ config, pkgs, ... }:
{
  # Shimboot-specific bootloader configuration
  # This integrates with the bootloader/ directory scripts
  boot.loader.grub.enable = false;
  boot.loader.systemd-boot.enable = false;

  # Kernel parameters for ChromeOS compatibility
  boot.kernelParams = [
    "console=ttyS0,115200n8"
    "no_timer_check"
    "console=tty0"
    "loglevel=7"
  ];

  # Initramfs configuration for shimboot
  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "ahci"
    "nvme"
    "usb_storage"
    "sd_mod"
    "rtsx_pci_sdmmc"
  ];

  # Add shimboot-specific packages
  environment.systemPackages = with pkgs; [
    # Add any shimboot-specific utilities here
  ];
}
