# Services Module
#
# Purpose: Configure user-level services for media, storage, and utilities
# Dependencies: None
# Related: None
#
# This module:
# - Enables media player control services
# - Configures storage management and clipboard tools
# - Sets up audio effects processing
{system, ...}: let
  isX86_64 = system == "x86_64-linux";
in {
  services = {
    playerctld.enable = true;
    mpris-proxy.enable = true;

    udiskie.enable = true;

    easyeffects.enable = true;

    cliphist.enable = true;
  };
}
