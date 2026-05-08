# SSH Daemon Configuration Module
#
# Purpose: Configure OpenSSH server for remote access
# Dependencies: openssh
# Related: networking.nix, security.nix
#
# This module:
# - Enables SSH daemon by default
# - Allows password authentication for accessibility
{
  lib,
  ...
}:
{
  services.openssh = {
    enable = lib.mkDefault true;
    settings.PasswordAuthentication = lib.mkDefault true;
  };
}
