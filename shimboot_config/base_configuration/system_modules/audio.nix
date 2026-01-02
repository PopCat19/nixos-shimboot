# Audio Configuration Module
#
# Purpose: Configure audio services for ChromeOS compatibility
# Dependencies: pipewire, alsa-utils
# Related: hardware.nix, services.nix
#
# This module enables:
# - PipeWire for modern audio routing
{lib, ...}: {
  services.pipewire = {
    enable = lib.mkDefault true;
  };
}
