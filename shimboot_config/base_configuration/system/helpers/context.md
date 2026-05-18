# Context

- bwrap-lsm-workaround.sh — Standalone bwrap wrapper that converts tmpfs to bind mounts for ChromeOS LSM compatibility (superseded by bwrap-safe in security.nix)
- bwrap-wrapper.sh — Transparent wrapper that intercepts bwrap calls and converts tmpfs to bind mounts (superseded by bwrap-safe in security.nix)
- expand-rootfs.sh — Expands root partition to full disk capacity
- fix-steam-bwrap.sh — Symlinks Steam's srt-bwrap to bwrap-safe (superseded by bwrap-mount-shim LD_PRELOAD approach; rots on Steam update)
- helpers.nix — Provide system packages for helper scripts with dependencies
- setup-bwrap-path.sh — Automatically integrates bwrap-wrapper into system PATH (deprecated; use explicit bwrap-safe prefix)
- setup-bwrap-workaround.sh — Configures bwrap workarounds for ChromeOS LSM restrictions (superseded by bwrap-safe in security.nix)
- migrate-hostname.sh — Migrates hostname configuration
- migrate-nixos-shimboot.sh — Migrates NixOS configuration
- migrate-username.sh — Migrates username configuration
- migration-status.sh — Checks migration status
- setup-nixos-shimboot.sh — Configure /etc/nixos for nixos-rebuild operations
- setup-nixos.sh — Interactive post-install setup wizard for NixOS shimboot