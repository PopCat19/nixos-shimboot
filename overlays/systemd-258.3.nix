# systemd-258.3.nix
#
# Purpose: Build patched systemd 258.3 from clean pkgs (not as overlay)
#
# This module:
# - Builds systemd 258.3 with ChromeOS compatibility patches
# - Takes pkgs as argument to avoid fixed-point recursion
# - Filters obsolete meson flags not present in 258.3
# - Injects libcap headers via preConfigure
{ pkgs }:
let
  version = "258.3";

  src = pkgs.fetchurl {
    url = "https://github.com/systemd/systemd/archive/refs/tags/v${version}.tar.gz";
    hash = "sha256-qAD6zC7/tQm/9ncAzhIk2pajb7ZY4p4DyEP7dPoe29w=";
  };

  mountpointPatch = pkgs.writeText "mountpoint-util.patch" ''
    diff --git a/src/basic/mountpoint-util.c b/src/basic/mountpoint-util.c
    index e8471d5..9fd2d1f 100644
    --- a/src/basic/mountpoint-util.c
    +++ b/src/basic/mountpoint-util.c
    @@ -661,25 +661,7 @@ int mount_nofollow(
                     const char *filesystemtype,
                     unsigned long mountflags,
                     const void *data) {
    -
    -        _cleanup_close_ int fd = -EBADF;
    -
    -        assert(target);
    -
    -        /* In almost all cases we want to manipulate the mount table without following symlinks, hence
    -         * mount_nofollow() is usually the way to go. The only exceptions are environments where /proc/ is
    -         * not available yet, since we need /proc/self/fd/ for this logic to work. i.e. during the early
    -         * initialization of namespacing/container stuff where /proc is not yet mounted (and maybe even the
    -         * fs to mount) we can only use traditional mount() directly.
    -         *
    -         * Note that this disables following only for the final component of the target, i.e symlinks within
    -         * the path of the target are honoured, as are symlinks in the source path everywhere. */
    -
    -        fd = open(target, O_PATH|O_CLOEXEC|O_NOFOLLOW);
    -        if (fd < 0)
    -                return -errno;
    -
    -        return mount_fd(source, fd, filesystemtype, mountflags, data);
    +        return RET_NERRNO(mount(source, target, filesystemtype, mountflags, data));
     }

     const char* mount_propagation_flag_to_string(unsigned long flags) {
  '';
in
pkgs.systemd.overrideAttrs (old: {
  inherit version src;
  mesonFlags = pkgs.lib.filter (
    f:
      !(
        pkgs.lib.hasInfix "swapon-path" f
        || pkgs.lib.hasInfix "swapoff-path" f
      )
  ) old.mesonFlags;
  patches = [ mountpointPatch ];
  preConfigure =
    (old.preConfigure or "")
    + ''
      export NIX_CFLAGS_COMPILE="$NIX_CFLAGS_COMPILE -I${pkgs.libcap.dev}/include"
      export NIX_LDFLAGS="$NIX_LDFLAGS -L${pkgs.libcap.lib}/lib -lcap"
    '';
})
