{ config, pkgs, lib, ... }:

{
  # Hardware Configuration
  hardware = {
    enableRedistributableFirmware = true; # Enable non-free firmware
    graphics = {
      enable = true;
      enable32Bit = true;
    };
    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
  };
}