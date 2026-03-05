# systemd-patch.nix
#
# Purpose: Provide systemd 258.3 with ChromeOS compatibility patches
#
# This module:
# - Provides systemd 258.3 tools system-wide (patched via overlay)
# - Uses overlay at overlays/systemd-258.3.nix for cachix caching
{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    systemd
  ];

  # Systemd 258.3 with mountpoint-util.patch is provided via overlays/systemd-258.3.nix
}
