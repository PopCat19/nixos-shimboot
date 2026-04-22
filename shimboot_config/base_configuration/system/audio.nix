# Audio Configuration Module
#
# Purpose: Configure audio services for ChromeOS compatibility
# Dependencies: pipewire, alsa-utils
# Related: hardware.nix, services.nix
#
# This module enables:
# - PipeWire for modern audio routing
{
  lib,
  config,
  ...
}:
let
  notHeadless = !config.shimboot.headless;
in
{
  config = lib.mkIf notHeadless {
    services.pipewire = {
      enable = lib.mkDefault true;
    };
  };
}
