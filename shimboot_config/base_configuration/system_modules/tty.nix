# TTY Configuration Module
#
# Purpose: Enable TTY fallback access and virtual console support
# Dependencies: kbd, util-linux, systemd
# Related: systemd.nix, boot.nix
#
# This module:
# - Enables getty services on VT3-VT6 (reserving VT1-2 for graphics)
# - Configures serial console as emergency fallback
# - Provides detailed console management tools
# - Ensures proper service ordering with kill-frecon
{
  config,
  pkgs,
  lib,
  ...
}: {
  # Don't use VT1 (display manager) or VT2 (user session)
  # Start getty on VT3-6
  systemd.services."getty@tty3" = {
    enable = lib.mkDefault true;
    # Wait for kill-frecon to finish before starting
    after = ["kill-frecon.service"];
    requires = ["kill-frecon.service"];
    serviceConfig = {
      StandardInput = "tty";
      StandardOutput = "tty";
      StandardError = "journal";
      TTYPath = "/dev/tty3";
      TTYReset = "yes";
      TTYVHangup = "yes";
      TTYVTDisallocate = "yes";
      Restart = "always";
      RestartSec = "0";
    };
  };
  
  systemd.services."getty@tty4" = {
    enable = lib.mkDefault true;
    after = ["kill-frecon.service"];
    requires = ["kill-frecon.service"];
    serviceConfig = {
      StandardInput = "tty";
      StandardOutput = "tty";
      StandardError = "journal";
      TTYPath = "/dev/tty4";
      TTYReset = "yes";
      TTYVHangup = "yes";
      TTYVTDisallocate = "yes";
      Restart = "always";
      RestartSec = "0";
    };
  };
  
  systemd.services."getty@tty5" = {
    enable = lib.mkDefault true;
    after = ["kill-frecon.service"];
    requires = ["kill-frecon.service"];
    serviceConfig = {
      StandardInput = "tty";
      StandardOutput = "tty";
      StandardError = "journal";
      TTYPath = "/dev/tty5";
      TTYReset = "yes";
      TTYVHangup = "yes";
      TTYVTDisallocate = "yes";
      Restart = "always";
      RestartSec = "0";
    };
  };
  
  systemd.services."getty@tty6" = {
    enable = lib.mkDefault true;
    after = ["kill-frecon.service"];
    requires = ["kill-frecon.service"];
    serviceConfig = {
      StandardInput = "tty";
      StandardOutput = "tty";
      StandardError = "journal";
      TTYPath = "/dev/tty6";
      TTYReset = "yes";
      TTYVHangup = "yes";
      TTYVTDisallocate = "yes";
      Restart = "always";
      RestartSec = "0";
    };
  };
  
  # Configure getty appearance
  services.getty = {
    autologinUser = lib.mkDefault null;
    helpLine = lib.mkDefault ''
      
      NixOS Shimboot Console
      
      Press Ctrl+Alt+F1 for display manager (LightDM)
      Press Ctrl+Alt+F2 for your graphical session (if logged in)
      Press Ctrl+Alt+F3-F6 to switch between text consoles
      
      Tip: Use 'ssh-info' to enable remote SSH access
    '';
  };
  
  # Enable serial console as emergency fallback
  systemd.services."serial-getty@ttyS0" = {
    enable = lib.mkDefault true;
    wantedBy = [ "getty.target" ];
    after = ["kill-frecon.service"];
    serviceConfig = {
      Restart = "always";
      RestartSec = "0";
      TTYVTDisallocate = "no";
      IgnoreSIGPIPE = "no";
    };
  };
  
  # Boot kernel params to enable console output
  boot.kernelParams = [
    "console=tty1"
    "console=ttyS0,115200n8"
  ];
  
  # Install TTY management tools
  environment.systemPackages = with pkgs; [
    kbd
    util-linux
    tmux
    
    (pkgs.writeShellScriptBin "tty-status" ''
      #!/usr/bin/env bash
      echo "=== TTY/Console Status ==="
      echo ""
      
      echo "Current TTY:"
      tty 2>/dev/null || echo "  Not in a TTY"
      echo ""
      
      echo "Current VT:"
      ${pkgs.kbd}/bin/fgconsole 2>/dev/null || echo "  Unable to detect VT"
      echo ""
      
      echo "Getty Services:"
      systemctl list-units 'getty@tty*' 'serial-getty@*' --no-legend --no-pager | \
        awk '{printf "  %-30s %s\n", $1, $3}' || echo "  No getty services found"
      echo ""
      
      echo "Console Device:"
      ls -l /dev/console 2>/dev/null || echo "  /dev/console not found"
      echo ""
      
      echo "VT Devices:"
      ls -l /dev/tty[1-6] 2>/dev/null | head -6 || echo "  No VT devices found"
      echo ""
      
      echo "kill-frecon Service:"
      systemctl status kill-frecon.service --no-pager -l | grep -E "Active:|Loaded:" || \
        echo "  kill-frecon service not found"
      echo ""
      
      echo "Kernel VT Support:"
      if zcat /proc/config.gz 2>/dev/null | grep -q 'CONFIG_VT=y'; then
        echo "  ✓ Kernel has CONFIG_VT=y"
      else
        echo "  ✗ Kernel lacks VT support (TTY switching may not work)"
      fi
      echo ""
      
      echo "Recent Getty Errors:"
      journalctl -u 'getty@*' --no-pager --since "10 minutes ago" | \
        grep -i "error\|failed\|unable" | tail -5 || echo "  No recent errors"
    '')
    
    (pkgs.writeShellScriptBin "fix-console" ''
      #!/usr/bin/env bash
      # Emergency console fix script
      echo "Attempting to fix console issues..."
      
      # Restart kill-frecon
      sudo systemctl restart kill-frecon.service
      
      # Restart getty services
      for tty in tty3 tty4 tty5 tty6; do
        echo "Restarting getty@$tty..."
        sudo systemctl restart "getty@$tty.service" || true
      done
      
      echo "Console services restarted. Check status with: tty-status"
    '')
  ];
  
  # Ensure getty.target waits for kill-frecon
  systemd.targets.getty = {
    after = ["kill-frecon.service"];
  };
}