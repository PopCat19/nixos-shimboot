# tools/rescue/context.md

## Overview

Interactive rescue toolkit for shimboot-based NixOS systems.
Provides filesystem operations, rebuild support, and recovery tools.

## Shell Scripts (Legacy)
- `rescue-helper.sh` — Legacy bash implementation (being replaced by Python)
- `cleanup-shimboot-rootfs.sh` — Cleans up shimboot rootfs artifacts

## Python Implementation

### Entry Point
- `rescue-helper.py` — Main TUI entry with fuzzy-searchable command menu

### Libraries (lib/)
- `console.py` — Rich-based colored output, tables, and live display
- `mounts.py` — Mount operations with automatic cleanup via context managers
- `system.py` — Root check, partition detection, system info
- `nix.py` — NixOS generation helpers and nix command wrappers
- `git_ops.py` — Git operations for config management

### Commands (commands/)
- `rebuild_nixos.py` — Auto-detect and rebuild NixOS system
- `chroot_shell.py` — Drop into chroot with Nix environment
- `show_configs.py` — List available nixos-config directories
- `remount.py` — Remount rootfs read-write or read-only
- `disk_usage.py` — Check disk and directory usage
- `fs_check.py` — Filesystem health check with e2fsck
- `generation_mgmt.py` — [UNTESTED] NixOS generation operations
- `bootloader_tools.py` — [UNTESTED] Bootloader inspection
- `home_mgmt.py` — [UNTESTED] Home directory backup/export
- `activation_script.py` — [UNTESTED] Stage-2 activation script

## Conventions

- Commands return int exit code (0 = success)
- Use context managers for mount operations
- Stream command output via Rich Live display
- All paths use Path objects, not strings
