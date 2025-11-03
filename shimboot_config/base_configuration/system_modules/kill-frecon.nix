# Kill Frecon Service Module
#
# Purpose: Configure service to kill frecon and prepare for X11
# Dependencies: systemd, util-linux, procps
# Related: systemd-patch.nix, display-manager.nix
#
# This module:
# - Provides systemd service to kill frecon-lite
# - Unmounts /dev/console for X11 compatibility
# - Ensures proper boot sequence for display manager
{
  config,
  pkgs,
  lib,
  ...
}: {
  systemd.services.kill-frecon = {
    description = "Kill frecon to allow X11 to start";
    wantedBy = ["graphical.target"];
    before = ["display-manager.service"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "kill-frecon" ''
        ${pkgs.util-linux}/bin/umount -l /dev/console 2>/dev/null || true
        ${pkgs.procps}/bin/pkill frecon-lite 2>/dev/null || true
      '';
    };
  };
}