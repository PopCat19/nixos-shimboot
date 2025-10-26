# Systemd Configuration Module
#
# Purpose: Configure systemd services and patches for shimboot
# Dependencies: systemd, kbd
# Related: boot.nix, services.nix, tty.nix
#
# This module:
# - Provides systemd tools system-wide
# - Applies patches to systemd for ChromeOS compatibility
# - Configures services for display management and login
# - Sets up kill-frecon service with proper timing
{
  config,
  pkgs,
  lib,
  self,
  ...
}: {
  environment.systemPackages = with pkgs; [
    systemd
    kbd  # For chvt command used in kill-frecon service
  ];

  systemd = {
    package = pkgs.systemd.overrideAttrs (old: {
      patches =
        (old.patches or [])
        ++ [
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
    
    services.kill-frecon = {
      description = "Kill frecon to allow X11 to start";
      wantedBy = ["graphical.target"];
      
      # Run after getty.target to allow TTYs to spawn first
      after = ["getty.target"];
      before = ["display-manager.service"];
      
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "kill-frecon" ''
          # Only unmount console if display manager is about to start
          ${pkgs.util-linux}/bin/umount -l /dev/console 2>/dev/null || true
          
          # Kill frecon-lite but give getty services time to spawn first
          sleep 2
          ${pkgs.procps}/bin/pkill frecon-lite 2>/dev/null || true
          
          # Ensure VT1 is available for display manager
          if ! ${pkgs.kbd}/bin/chvt 1 2>/dev/null; then
            echo "Warning: chvt failed - VT switching may not be supported" >&2
          fi
        '';
      };
    };
  };

  services.accounts-daemon.enable = true;

  services.logind = {
    settings = {
      Login = {
        # Power management
        HandleLidSwitch = "ignore";
        HandlePowerKey = "ignore";
        HandleSuspendKey = "ignore";
        HandleHibernateKey = "ignore";
        
        # TTY/VT configuration
        NAutoVTs = lib.mkDefault 6;
        ReserveVT = lib.mkDefault 7;
      };
    };
  };
}
