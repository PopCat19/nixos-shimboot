{ config, pkgs, lib, ... }:

{
  # Filesystem Configuration
  fileSystems."/" = lib.mkForce { # Root filesystem configuration (forced to override raw-efi defaults)
    device = "/dev/disk/by-partlabel/shimboot_rootfs:nixos";
    fsType = "ext4";
  };
  
  fileSystems."/boot" = lib.mkForce { # /boot filesystem configuration (forced to override raw-efi defaults)
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
}