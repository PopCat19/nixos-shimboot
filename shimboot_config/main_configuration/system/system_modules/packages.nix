# System Packages Module
#
# Purpose: Install system-wide packages
# Dependencies: None
# Related: None
#
# This module:
# - Installs system-wide utility packages
{ pkgs, self, ... }:
{
  environment.systemPackages = with pkgs; [
    gh
    ranger
    kdePackages.dolphin
    libmtp
    kdePackages.kio-extras
    simple-mtpfs
    usbutils
    android-tools
    self.inputs.llm-agents.packages.${pkgs.system}.opencode
  ];
}
