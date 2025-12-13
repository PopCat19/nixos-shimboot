# SSH Configuration Module
#
# Purpose: Configure OpenSSH service with secure authentication
# Dependencies: systemd, openssh
# Related: services.nix, security.nix
#
# This module:
# - Enables OpenSSH daemon
# - Configures password-based authentication
# - Permits root login for remote access
{
  pkgs,
  lib,
  ...
}: {
  services = {
    openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = true;
        PermitRootLogin = "yes";
      };
    };
  };
}