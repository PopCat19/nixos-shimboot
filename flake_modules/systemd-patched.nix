{ self, nixpkgs, ... }:
let
  system = "x86_64-linux";
  pkgs = nixpkgs.legacyPackages.${system};
in {
  # Standalone package to build patched systemd (same patch behavior as used in NixOS module)
  packages.${system}.systemd-patched =
    pkgs.systemd.overrideAttrs (old: {
      # Disable tests only; keep standard meson install hooks intact
      doCheck = false;
      # Apply precise unified diff generated against nixpkgs systemd-257.6
      patches = (old.patches or []) ++ [
        (pkgs.writeText "mountpoint-util.patch" ''
          --- a/src/basic/mountpoint-util.c
          +++ b/src/basic/mountpoint-util.c
          @@ -679,7 +679,7 @@ int mount_nofollow(
                   if (fd < 0)
                           return -errno;
           
          -        return mount_fd(source, fd, filesystemtype, mountflags, data);
          +        return RET_NERRNO(mount(source, target, filesystemtype, mountflags, data));
           }
           
           const char* mount_propagation_flag_to_string(unsigned long flags) {
        '')
      ];
    });
}