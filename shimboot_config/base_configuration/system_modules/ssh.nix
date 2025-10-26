# SSH Configuration Module
#
# Purpose: Enable SSH remote access for reliable console management
# Dependencies: openssh, networkmanager
# Related: networking.nix, security.nix
#
# This module:
# - Configures OpenSSH server with secure defaults
# - Ensures network is fully online before SSH starts
# - Provides helper script for connection information
# - Opens firewall port for SSH access
{
  config,
  pkgs,
  lib,
  userConfig,
  ...
}: {
  services.openssh = {
    enable = lib.mkDefault true;
    
    # Security settings
    settings = {
      PermitRootLogin = lib.mkDefault "no";
      PasswordAuthentication = lib.mkDefault true;  # Change to false after setting up keys
      KbdInteractiveAuthentication = lib.mkDefault false;
      PermitEmptyPasswords = lib.mkDefault false;
      
      # Allow X11 forwarding (useful for remote GUI apps)
      X11Forwarding = lib.mkDefault true;
      X11UseLocalhost = lib.mkDefault true;  # Boolean, not string
      
      # Security hardening
      MaxAuthTries = lib.mkDefault 3;
      ClientAliveInterval = lib.mkDefault 300;
      ClientAliveCountMax = lib.mkDefault 2;
    };
    
    # Open firewall port
    openFirewall = lib.mkDefault true;
  };
  
  # Ensure NetworkManager waits for network to be actually online
  systemd.services.NetworkManager-wait-online = {
    enable = lib.mkDefault true;
    wantedBy = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.networkmanager}/bin/nm-online -q";
      RemainAfterExit = true;
      TimeoutStartSec = "120";  # 2 minutes for slow WiFi
    };
  };
  
  # Helper script to show SSH connection info
  environment.systemPackages = with pkgs; [
    openssh
    
    (pkgs.writeShellScriptBin "ssh-info" ''
      #!/usr/bin/env bash
      echo "=== SSH Server Status ==="
      systemctl status sshd --no-pager -l | grep "Active:" || echo "SSH service not running"
      echo ""
      echo "=== Network Interfaces ==="
      ip -4 -brief addr show | grep -v "127.0.0.1" || echo "No IPv4 addresses found"
      echo ""
      echo "=== Connection Commands ==="
      echo "  ssh ${userConfig.user.username}@<ip-address>"
      echo ""
      echo "=== SSH Configuration ==="
      echo "  Password authentication: $(grep '^PasswordAuthentication' /etc/ssh/sshd_config | awk '{print $2}' || echo 'unknown')"
      echo "  Root login: $(grep '^PermitRootLogin' /etc/ssh/sshd_config | awk '{print $2}' || echo 'unknown')"
      echo ""
      echo "=== Setup SSH Keys (Recommended) ==="
      echo "  1. On your main machine:"
      echo "     ssh-copy-id ${userConfig.user.username}@<chromebook-ip>"
      echo ""
      echo "  2. Then disable password auth in ssh.nix:"
      echo "     PasswordAuthentication = lib.mkForce false;"
      echo ""
      echo "  3. Rebuild: sudo nixos-rebuild switch"
    '')
  ];
  
  # Firewall rules (if enabled)
  networking.firewall = {
    enable = lib.mkDefault false;
    allowedTCPPorts = lib.mkDefault [ 22 ];
  };
  
  # Ensure SSH service restarts on failure and starts after network
  systemd.services.sshd = {
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    requires = [ "network-online.target" ];
    serviceConfig = {
      Restart = lib.mkDefault "on-failure";
      RestartSec = lib.mkDefault "5s";
    };
  };
}