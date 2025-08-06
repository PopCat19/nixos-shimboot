{ config, pkgs, lib, ... }:

{
  # Networking Configuration
  networking = {
    dhcpcd.enable = false; # Disable dhcpcd in favor of NetworkManager
    firewall.enable = false; # Disables the firewall
    networkmanager.enable = true; # Enable NetworkManager
  };
}