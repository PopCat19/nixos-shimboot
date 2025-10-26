# TTY Configuration Module
#
# Purpose: Enable TTY fallback access and virtual console support
# Dependencies: kbd, systemd
# Related: systemd.nix, boot.nix
#
# This module:
# - Enables getty services on VT2-VT6 for fallback console access
# - Configures serial console as emergency fallback
# - Sets up proper VT allocation with logind
# - Provides TTY switching tools and kernel console parameters
{
  config,
  pkgs,
  lib,
  ...
}: {
  # Enable getty on VT2-VT6 (VT1 is used by display manager)
  systemd.services."getty@tty2".enable = lib.mkDefault true;
  systemd.services."getty@tty3".enable = lib.mkDefault true;
  systemd.services."getty@tty4".enable = lib.mkDefault true;
  systemd.services."getty@tty5".enable = lib.mkDefault true;
  systemd.services."getty@tty6".enable = lib.mkDefault true;
  
  # Ensure autologin is disabled on TTYs (security)
  services.getty = {
    autologinUser = lib.mkDefault null;
    helpLine = lib.mkDefault ''
      NixOS Shimboot - TTY Login
      
      Press Ctrl+Alt+F1 to return to graphical session.
      Use SSH for remote access if TTY switching fails.
    '';
  };
  
  # Enable serial console as fallback (useful if VTs fail)
  systemd.services."serial-getty@ttyS0" = {
    enable = lib.mkDefault true;
    wantedBy = [ "getty.target" ];
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
  
  # Install useful TTY tools
  environment.systemPackages = with pkgs; [
    kbd  # chvt, setfont commands
    tmux  # Terminal multiplexer for serial console
    
    (pkgs.writeShellScriptBin "tty-info" ''
      #!/usr/bin/env bash
      echo "=== TTY/VT Status ==="
      echo ""
      echo "Active TTY:"
      tty || echo "Not running in a TTY"
      echo ""
      echo "Current VT:"
      ${pkgs.kbd}/bin/fgconsole 2>/dev/null || echo "VT info not available"
      echo ""
      echo "Getty Services:"
      systemctl list-units 'getty@*' 'serial-getty@*' --no-legend | grep -E 'getty@tty[2-6]|serial-getty@ttyS0' || echo "No getty services running"
      echo ""
      echo "=== VT Switching ==="
      echo "Press Ctrl+Alt+F1 for graphical session"
      echo "Press Ctrl+Alt+F2-F6 for text consoles"
      echo "Use 'sudo chvt N' to switch to VT N"
      echo ""
      echo "=== Kernel VT Support ==="
      if zcat /proc/config.gz 2>/dev/null | grep -q 'CONFIG_VT=y'; then
        echo "✓ Kernel has VT support"
      else
        echo "✗ Kernel may lack VT support (use SSH/serial console)"
      fi
    '')
  ];
}