# Audio Configuration Module
#
# Purpose: Configure audio services for ChromeOS compatibility
# Dependencies: pipewire, alsa-utils
# Related: hardware.nix, services.nix
#
# This module enables:
# - PipeWire for modern audio routing
# - ALSA utilities for legacy compatibility
# - PulseAudio compatibility layer

{...}: {
  services.pipewire = {
    enable = true;
    alsa = {
      enable = true;
      support32Bit = true;
    };
    pulse.enable = true;
  };
}
