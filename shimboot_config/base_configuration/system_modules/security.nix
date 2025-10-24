# Security Configuration Module
#
# Purpose: Configure system security and authorization
# Dependencies: polkit
# Related: services.nix, users.nix
#
# This module:
# - Enables PolicyKit for system authorization
# - Provides secure privilege escalation mechanisms

{
  config,
  pkgs,
  lib,
  ...
}: {
  security.polkit.enable = true;
}
