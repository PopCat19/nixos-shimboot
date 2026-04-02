# System Packages Module
#
# Purpose: Install system-wide packages
# Dependencies: None
# Related: None
#
# This module:
# - Installs system-wide utility packages
{ pkgs, inputs, ... }:
{
  environment.systemPackages = with pkgs; [
    gh
    ranger
    kdePackages.dolphin
    kdePackages.kio-extras
    usbutils
    android-tools
    tree
    xdg-utils
    nodejs
    python3
    rustup
    jql
    eza
    inputs.llm-agents.packages.${pkgs.system}.kilocode-cli
    inputs.llm-agents.packages.${pkgs.system}.opencode
  ];
}
