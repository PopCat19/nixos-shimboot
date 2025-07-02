{ config, pkgs, lib, ... }:
{
  imports = []; # Allows importing other configuration files

  # Bootloader Configuration
  boot = {
    loader = {
      grub.enable = false; # Disables GRUB bootloader
      systemd-boot.enable = false; # Disables systemd-boot bootloader
      initScript.enable = true; # Enables the init script
    };
    initrd = {
      availableKernelModules = [ # Modules available in the initrd
        "atkbd" # PS/2 keyboard
        "i8042" # PS/2 controller
        "serio_raw" # raw serio interface
        "usbcore"
        "usbhid"
        "hid_generic"
        "tun" # TUN/TAP networking support
        "iwlmvm" # Intel wireless
        "ccm" # Counter with CBC-MAC
        "8021q" # VLAN support
        "zram" # Compressed RAM
        "lzo" # LZO compression
      ];
      kernelModules = []; # Modules to be included in the kernel
    };
    kernelParams = [ ]; # Kernel parameters
    isContainer = lib.mkForce false; # Force disable container mode
  };

  # System Configuration
  system = {
    stateVersion = "24.11"; # NixOS version
    copySystemConfiguration = true; # Copies the system configuration
    activationScripts.traditionalLayout = '' # Creates traditional Unix filesystem layout
      mkdir -p /sbin /usr/sbin
      ln -sf /init /sbin/init
      ln -sf /init /usr/sbin/init

      # X11 utilities
      ln -sf /run/current-system/sw/bin/xrdb /usr/bin/xrdb

      # Core utilities in traditional locations
      ln -sf /run/current-system/sw/bin/coreutils /usr/bin/coreutils
    '';
  };

  # Networking Configuration
  networking = {
    dhcpcd.enable = true; # Enables dhcpcd for network configuration
    useDHCP = true; # Use DHCP
    firewall.enable = false; # Disables the firewall
  };
  services.resolved.enable = true; # Enables systemd-resolved for DNS resolution
  # systemd.network.enable = true; # Conflicts with dhcpcd

  # ZRAM Swap Configuration
  zramSwap = {
    enable = true; # Enables ZRAM swap
    algorithm = "lzo"; # LZO compression algorithm
    memoryPercent = 100; # Use all available RAM for ZRAM
  };

  # Filesystem Configuration
  fileSystems."/" = lib.mkForce { # Root filesystem configuration
    device = "/dev/disk/by-partlabel/shimboot_rootfs:nixos";
    fsType = "ext4";
  };
  fileSystems."/boot" = { # /boot filesystem configuration
    device = "tmpfs";
    fsType = "tmpfs";
  };
  systemd.mounts = [ # Mounts configuration
    {
      what = "tmpfs";
      where = "/tmp";
      type = "tmpfs";
      options = "defaults,size=0"; # Effectively disables it by setting size to 0
    }
  ];

  # Package Configuration
  environment.systemPackages = with pkgs; [ # System-wide packages
    busybox
    util-linux
    coreutils
    bash
    nano
    micro
    btop
    file
    which
    ranger
    kbd
    xorg.xrandr
    xorg.xdpyinfo
    xorg.xset
    procps
    psmisc
    fbset
    cloud-utils
    sudo
    bash-completion
    fuse
    networkmanager
    wpa_supplicant

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

  # User Configuration
  users = {
    users = {
      root = { # Root user configuration
        password = "";
        shell = pkgs.bash;
      };
      "nixos-user" = { # Regular user configuration
        isNormalUser = true;
        password = "";
        shell = pkgs.fish;
        extraGroups = [ "wheel" "video" "audio" "networkmanager" "tty" ];
      };
    };
    allowNoPasswordLogin = true; # Allow login without password
  };
  security.pam.services.login.allowNullPassword = true; # Allow null password for login
  security.pam.services.passwd.allowNullPassword = true; # Allow null password for passwd

  # Systemd Configuration
  systemd = {
    package = pkgs.systemd.overrideAttrs (old: { # Overrides systemd package attributes
      patches = (old.patches or []) ++
        [ ./nix/patches/systemd_unstable.patch ];
    });
    services.kill-frecon = { # Service to kill frecon
      description = "Kill frecon to allow X11 to start";
      wantedBy = [ "graphical.target" ];
      before = [ "display-manager.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "kill-frecon" ''
          ${pkgs.util-linux}/bin/umount -l /dev/console 2>/dev/null || true
          ${pkgs.procps}/bin/pkill frecon-lite 2>/dev/null || true
        '';
      };
    };
  };

  # Console and Localization
  time.timeZone = "America/New_York"; # Timezone
  i18n.defaultLocale = "en_US.UTF-8"; # Default locale
  users.motd = '' # Message of the day
    Welcome to NixOS Shimboot!
    For documentation and to report bugs, please visit the project's Github page.

    Run 'expand_rootfs' if you need to expand the root filesystem.
    Run 'shimboot_greeter' for system information.
  '';
  programs.fish.enable = true; # Enables fish shell

  # X11 and Display Manager Configuration
  services.xserver = {
    enable = true; # Enables X server
    xkb.layout = "us"; # Keyboard layout
    displayManager = {
      lightdm = { # LightDM display manager configuration
        enable = true;
        greeters.gtk.enable = true;
        greeters.gtk.theme.name = "Nordic";
        greeters.gtk.iconTheme.name = "Papirus-Dark";
      };
    };
    videoDrivers = [ "modesetting" "fbdev" "vesa" ]; # Video drivers
    desktopManager = {
      xfce = { # XFCE desktop manager configuration
        enable = true;
        enableXfwm = true;
      };
    };
  };
  services.displayManager.autoLogin = { # Autologin configuration
      enable = true;
      user = "root";
    };
  services.logind = { # Logind service configuration
    lidSwitch = "ignore";
    extraConfig = ''
      HandlePowerKey=ignore
      HandleSuspendKey=ignore
      HandleHibernateKey=ignore
    '';
  };
  security.polkit.enable = true; # Enables polkit for authorization
}
