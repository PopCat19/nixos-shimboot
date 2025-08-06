{ config, pkgs, lib, ... }:

{
  # Systemd Configuration
  systemd = {
    package = pkgs.systemd.overrideAttrs (old: { # Overrides systemd package attributes
      patches = (old.patches or []) ++
        [
          # Patch for mountpoint-util.c to use direct mount() call instead of mount_nofollow()
          (pkgs.writeText "mountpoint-util.patch" ''
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
          '')
        ];
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
  
  # Services Configuration
  services.accounts-daemon.enable = true; # Enable AccountsService for PolicyKit
  
  services.logind = { # Logind service configuration
    lidSwitch = "ignore";
    extraConfig = ''
      HandlePowerKey=ignore
      HandleSuspendKey=ignore
      HandleHibernateKey=ignore
    '';
  };
}