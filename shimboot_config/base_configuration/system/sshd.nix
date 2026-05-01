# SSH Daemon Configuration Module
#
# Purpose: Configure OpenSSH server for remote access
# Dependencies: openssh
# Related: networking.nix, security.nix
#
# This module:
# - Enables SSH daemon with headless gating
# - Allows password authentication for accessibility
{
  lib,
  config,
  ...
}:
let
  inherit (config.shimboot) headless;
in
{
  services.openssh = lib.mkIf headless {
    enable = lib.mkDefault true;
    settings.PasswordAuthentication = lib.mkDefault true;
  };
}