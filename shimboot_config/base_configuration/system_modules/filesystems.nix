{
  config,
  pkgs,
  lib,
  ...
}: {
  # Filesystem Configuration for single partition rootfs
  fileSystems."/" = lib.mkForce {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  # Remove /boot filesystem as it's not needed for single partition setup
  # The kernel and initramfs will be loaded directly from the root partition

  # Configure tmpfs for /tmp with reasonable limits
  systemd.mounts = [
    {
      what = "tmpfs";
      where = "/tmp";
      type = "tmpfs";
      options = "defaults,size=2G";
    }
  ];
}
