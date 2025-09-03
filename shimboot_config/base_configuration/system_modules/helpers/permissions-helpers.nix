{ config, pkgs, lib, userConfig, ... }:

{
  # Helper shell scripts packaged as binaries
  environment.systemPackages = with pkgs; [
    (writeShellScriptBin "fix_bwrap" '' # Script to fix bwrap permissions
      # NixOS equivalent of shimboot's fix_bwrap script
      set -e

      if [ ! "$HOME_DIR" ]; then
        sudo HOME_DIR="$HOME" $0
        exit 0
      fi

      fix_perms() {
        local target_file="$1"
        chown root:root "$target_file"
        chmod u+s "$target_file"
      }

      echo "Fixing permissions for /usr/bin/bwrap"
      if [ -f "/usr/bin/bwrap" ]; then
        fix_perms /usr/bin/bwrap
      fi

      if [ ! -d "$HOME_DIR/.steam/" ]; then
        echo "Steam not installed, so exiting early."
        echo "Done."
        exit 0
      fi

      echo "Fixing permissions bwrap binaries in Steam"
      steam_bwraps="$(find "$HOME_DIR/.steam/" -name 'srt-bwrap' 2>/dev/null || true)"
      for bwrap_bin in $steam_bwraps; do
        if [ -f "/usr/bin/bwrap" ]; then
          cp /usr/bin/bwrap "$bwrap_bin"
          fix_perms "$bwrap_bin"
        fi
      done

      echo "Done."
    '')
  ];
}