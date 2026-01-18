# Shimboot Host Configuration
#
# Purpose: Main system configuration for shimboot host
# Dependencies: modules/nixos/*, modules/nixos/profiles/shimboot
# Related: hosts/shimboot/home.nix
#
# This configuration:
# - Imports core system modules
# - Imports desktop environment modules
# - Imports hardware modules
# - Imports shimboot-specific profile
{ pkgs, inputs, ... }:
{
  imports = [
    # System modules
    ../../modules/nixos/core
    ../../modules/nixos/desktop
    ../../modules/nixos/hardware
    ../../modules/nixos/profiles/shimboot

    # Add hardware-configuration.nix if it exists
    # ./hardware-configuration.nix
  ];

  networking.hostName = "shimboot";

  # Host-specific system packages
  environment.systemPackages = with pkgs; [
    # Add host-specific packages here
  ];
}
