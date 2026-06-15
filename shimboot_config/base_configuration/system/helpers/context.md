# Context

- bwrap-lsm-workaround.sh, Standalone tmpfs→bind wrapper (superseded by bwrap-mount-shim LD_PRELOAD approach)
- bwrap-wrapper.sh, Transparent bwrap tmpfs→bind interceptor (superseded by bwrap-mount-shim)
- expand-rootfs.sh, Expands root partition to full disk capacity
- fix-steam-bwrap.sh, Legacy symlink patch for Steam's srt-bwrap (superseded by bwrap-mount-shim; rots on Steam update)
- helpers.nix, Provide system packages for helper scripts with dependencies
- setup-bwrap-path.sh, Legacy PATH integration for bwrap-wrapper (superseded by bwrap-mount-shim)
- setup-bwrap-workaround.sh, Legacy bwrap workaround configuration (superseded by bwrap-mount-shim)
- migrate-hostname.sh, Migrates hostname configuration
- migrate-nixos-shimboot.sh, Migrates NixOS configuration
- migrate-username.sh, Migrates username configuration
- migration-status.sh, Checks migration status
- setup-nixos-shimboot.sh, Configure /etc/nixos for nixos-rebuild operations
- setup-nixos.sh, Interactive post-install setup wizard for NixOS shimboot