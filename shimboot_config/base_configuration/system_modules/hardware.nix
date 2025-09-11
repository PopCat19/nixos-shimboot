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
      enable32Bit = userConfig.arch.isX86_64; # Only enable 32-bit graphics on x86_64
    };
    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
  };
}
