# Security Configuration Module
#
# Purpose: Configure system security and authorization
# Dependencies: polkit, rtkit
# Related: services.nix, users.nix
#
# This module:
# - Enables PolicyKit for system authorization
# - Enables rtkit for realtime scheduling
# - Provides secure privilege escalation mechanisms
{
  config,
  pkgs,
  lib,
  ...
}: {
  security.polkit.enable = true;
  security.rtkit.enable = true;
}
