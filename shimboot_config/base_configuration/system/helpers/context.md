# Context

- bwrap-lsm-workaround.sh — Wrapper for bwrap that converts tmpfs to bind mounts for ChromeOS LSM compatibility
- bwrap-wrapper.sh — Transparent wrapper that intercepts bwrap calls and converts tmpfs to bind mounts
- expand-rootfs.sh — Expands root partition to full disk capacity
- fix-steam-bwrap.sh — Fixes Steam bwrap issues on NixOS
- helpers.nix — Provides helper functions for system configuration
- setup-bwrap-path.sh — Automatically integrates bwrap-wrapper into system PATH
- setup-bwrap-workaround.sh — Configures bwrap workarounds for ChromeOS LSM restrictions
- migrate-hostname.sh — Migrates hostname configuration
- migrate-nixos-config.sh — Migrates NixOS configuration
- migrate-username.sh — Migrates username configuration
- migration-status.sh — Checks migration status
- setup-nixos-config.sh — Sets up NixOS configuration
- setup-nixos.sh — Main NixOS setup script
