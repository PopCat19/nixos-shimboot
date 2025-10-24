{
  config,
  pkgs,
  lib,
  userConfig,
  ...
}: {
  # Hardware Configuration
  hardware = {
    enableRedistributableFirmware = true; # Enable non-free firmware
    graphics = {
      enable = true;
      enable32Bit = true; # Enable 32-bit graphics support
    };
    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
  };
}
