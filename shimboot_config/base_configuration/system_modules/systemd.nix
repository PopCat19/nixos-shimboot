# Systemd Configuration Module
#
# Purpose: Configure systemd services and patches for shimboot
# Dependencies: systemd, kbd, util-linux
# Related: boot.nix, services.nix, tty.nix
#
# This module:
# - Provides systemd tools system-wide
# - Applies patches to systemd for ChromeOS compatibility
# - Configures kill-frecon service with proper console preparation
# - Sets up logind with TTY/VT configuration
{
  config,
  pkgs,
  lib,
  self,
  ...
}: {
  environment.systemPackages = with pkgs; [
    systemd
    kbd
    util-linux
  ];

  systemd = {
    package = pkgs.systemd.overrideAttrs (old: {
      patches =
        (old.patches or[])
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
      description = "Kill frecon and prepare console for getty";
      wantedBy = ["multi-user.target"];  # Start earlier
      
      # CRITICAL: Must run BEFORE getty.target
      before = ["getty.target" "graphical.target" "display-manager.service"];
      after = ["local-fs.target"];
      
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        StandardOutput = "journal+console";
        StandardError = "journal+console";
        ExecStart = pkgs.writeShellScript "kill-frecon" ''
          set -x
          echo "[kill-frecon] Starting console cleanup"
          
          # Kill frecon-lite forcefully
          if ${pkgs.procps}/bin/pgrep frecon-lite >/dev/null 2>&1; then
            echo "[kill-frecon] Killing frecon-lite"
            ${pkgs.procps}/bin/pkill -9 frecon-lite 2>/dev/null || true
            sleep 1
          fi
          
          # Unmount any existing console mounts
          echo "[kill-frecon] Unmounting /dev/console"
          ${pkgs.util-linux}/bin/umount -l /dev/console 2>/dev/null || true
          
          # Ensure /dev/console exists as a proper character device
          if [ ! -c /dev/console ]; then
            echo "[kill-frecon] Creating /dev/console device node"
            mknod -m 600 /dev/console c 5 1 2>/dev/null || true
          fi
          
          # Bind console to tty0 (kernel's current console)
          # This makes /dev/console usable for both display manager and getty
          echo "[kill-frecon] Binding /dev/console to /dev/tty0"
          mount --bind /dev/tty0 /dev/console 2>/dev/null || true
          
          # Reset console state
          echo "[kill-frecon] Resetting console state"
          ${pkgs.kbd}/bin/setfont 2>/dev/null || true
          
          # Make VT1 active (for display manager)
          echo "[kill-frecon] Switching to VT1"
          ${pkgs.kbd}/bin/chvt 1 2>/dev/null || echo "[kill-frecon] chvt failed (might not be supported)"
          
          # Give system time to stabilize
          sleep 1
          
          echo "[kill-frecon] Console prepared for getty services"
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
        # Reserve VT1-2 for display manager and user session
        NAutoVTs = 6;
        ReserveVT = 7;
      };
    };
  };
}
