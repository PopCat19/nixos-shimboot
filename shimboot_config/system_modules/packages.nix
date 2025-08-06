{ config, pkgs, lib, ... }:

{
  # Package Configuration
  environment.systemPackages = with pkgs; [ # System-wide packages
    micro
    btop
    kitty # Terminal emulator
    lightdm # Display manager
    xdg-desktop-portal-hyprland # XDG desktop portal backend for Hyprland

    (writeShellScriptBin "expand_rootfs" '' # Script to expand the root filesystem
      # NixOS equivalent of shimboot's expand_rootfs script
      set -e
      if [ "$DEBUG" ]; then
        set -x
      fi

      if [ "$EUID" -ne 0 ]; then
        echo "This needs to be run as root."
        exit 1
      fi

      root_dev="$(findmnt -T / -no SOURCE)"
      luks="$(echo "$root_dev" | grep "/dev/mapper" || true)"

      if [ "$luks" ]; then
        echo "Note: Root partition is encrypted."
        kname_dev="$(lsblk --list --noheadings --paths --output KNAME "$root_dev")"
        kname="$(basename "$kname_dev")"
        part_dev="/dev/$(basename "/sys/class/block/$kname/slaves/"*)"
      else
        part_dev="$root_dev"
      fi

      disk_dev="$(lsblk --list --noheadings --paths --output PKNAME "$part_dev" | head -n1)"
      part_num="$(echo "''${part_dev#$disk_dev}" | tr -d 'p')"

      echo "Automatically detected root filesystem:"
      fdisk -l "$disk_dev" 2>/dev/null | grep "''${disk_dev}:" -A 1
      echo
      echo "Automatically detected root partition:"
      fdisk -l "$disk_dev" 2>/dev/null | grep "''${part_dev}"
      echo
      read -p "Press enter to continue, or ctrl+c to cancel. "

      echo
      echo "Before:"
      df -h /

      echo
      echo "Expanding the partition and filesystem..."
      ${cloud-utils}/bin/growpart "$disk_dev" "$part_num" || true
      if [ "$luks" ]; then
        /bootloader/bin/cryptsetup resize "$root_dev"
      fi
      ${e2fsprogs}/bin/resize2fs "$root_dev" || true

      echo
      echo "After:"
      df -h /

      echo
      echo "Done expanding the root filesystem."
    '')

    (writeShellScriptBin "shimboot_greeter" '' # Greeter script
      # Get storage stats
      percent_full="$(df -BM / | tail -n1 | awk '{print $5}' | tr -d '%')"
      total_size="$(df -BM / | tail -n1 | awk '{print $2}' | tr -d 'M')"

      # Print the greeter
      echo "Welcome to NixOS Shimboot!"
      echo "For documentation and to report bugs, please visit the project's Github page:"
      echo " - https://github.com/popcat19/nixos-shimboot"

      # Check if rootfs needs expansion (same logic as shimboot)
      if [ "$percent_full" -gt 80 ] && [ "$total_size" -lt 7000 ]; then
        echo
        echo "Warning: Your storage is nearly full and you have not yet expanded the root filesystem. Run 'sudo expand_rootfs' to fix this."
      fi

      echo
    '')

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