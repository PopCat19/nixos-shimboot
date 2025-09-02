{ config, pkgs, lib, ... }:

{
  # Networking Configuration
  networking = {
    dhcpcd.enable = false; # Disable dhcpcd in favor of NetworkManager
    firewall = {
      enable = true;
      # network overrides deprecated — use canonical defaults here
      trustedInterfaces = [ "lo" ];
      allowedTCPPorts = [
        22      # SSH
        53317   # Syncthing
      ];
      allowedUDPPorts = [
        53317   # Syncthing
      ];
      checkReversePath = false;
    };
    hostName = "nixos-shimboot"; # Ensure $HOSTNAME matches flake attribute after first switch
    networkmanager = {
      enable = true; # Enable NetworkManager
      wifi.backend = "wpa_supplicant"; # Use wpa_supplicant for WiFi (more compatible with ChromeOS)
      wifi.powersave = false; # Disable WiFi power saving to prevent connectivity issues
    };
    wireless.enable = false; # Disable NixOS wireless when using NetworkManager
  };

  # Load WiFi modules at boot (matching upstream shimboot configuration)
  boot.kernelModules = [ "iwlmvm" "ccm" "8021q" "tun" ];

  # Handle potential rfkill issues on ChromeOS devices
  system.activationScripts.rfkillUnblockWlan = {
    text = ''
      ${pkgs.util-linux}/bin/rfkill unblock wlan
    '';
    deps = [];
  };
}