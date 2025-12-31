# System Packages Module
#
# Purpose: Install system-wide packages
# Dependencies: None
# Related: None
#
# This module:
# - Provides placeholder for system packages
{
  pkgs,
  userConfig,
  ...
}: {
  environment.systemPackages = with pkgs; [
    gh
    ranger
  ];
}
