{ config, pkgs, lib, ... }:

{
  # Bootloader Configuration
  boot = {
    loader = {
      grub.enable = false; # Disables GRUB bootloader
      systemd-boot.enable = false; # Disables systemd-boot bootloader
      initScript.enable = true; # Enables the init script
    };
    initrd = {
      availableKernelModules = [];
      kernelModules = []; # Modules to be included in the kernel
    };
    kernelParams = [ ]; # Kernel parameters
  };
}