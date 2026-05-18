## Overview

> [!WARNING]
> Untested. The scripts exist but have not been verified working on any board so far.

ChromeOS's security model includes a Linux Security Module (LSM) called `chromiumos` that restricts certain operations, including mounting tmpfs filesystems. This causes issues with `bwrap` (bubblewrap), which is commonly used for sandboxing applications like Steam, AppImages, and various Nix packages.

## Problem

When applications try to use `bwrap` with tmpfs mounts, they encounter:

```
bwrap: Failed to mount tmpfs: Operation not permitted
```

This occurs because the ChromeOS LSM blocks tmpfs mounts even when running as root or with SUID permissions.

## Solution

A single tool, `bwrap-mount-shim`, uses `LD_PRELOAD` to intercept `mount()` calls at the libc level and convert `tmpfs` mounts to `bind` mounts (which the ChromeOS LSM allows). It works transparently for everything — no argument parsing, no per-application configuration.

```bash
bwrap-mount-shim steam                    # Steam, Flatpak (transparent LD_PRELOAD)
bwrap-mount-shim ./myapp                  # auto-sandbox with bwrap defaults
bwrap-mount-shim --ro-bind / / -- ... --  # explicit bwrap control
```

The first form only sets `LD_PRELOAD` — the program runs its own bwrap internally, and the shim intercepts tmpfs at the mount() level.

The second form auto-wraps the command in a bwrap sandbox with sensible defaults (`ro-bind /`, `/dev`, `/proc`, `tmpfs /tmp`).

## Implementation

### Security Configuration

The [`security.nix`](shimboot_config/base_configuration/system/security.nix) module provides:

- `bwrap` — SUID wrapper for namespace creation (ChromeOS kernels restrict unprivileged user namespaces)
- `bwrap-mount-shim` — LD_PRELOAD shim compiled from [`mount_shim.c`](patches/bwrap-mount-shim.c), plus a convenience wrapper script

The C shim intercepts `mount("tmpfs", ...)` calls, creates a unique directory via `mkdtemp` under `$BWRAP_CACHE_DIR` (default: `/tmp/bwrap-cache`), and converts the call to `mount("bind", ...)`. Created directories are cleaned up on normal exit via `atexit`.

### Steam Integration

Steam's pressure-vessel runtime uses an internal `srt-bwrap` binary. The LD_PRELOAD shim intercepts `mount()` inside that process, so `bwrap-mount-shim steam` is all that's needed — no symlink patching, survives Steam updates.

The legacy [`fix-steam-bwrap.sh`](shimboot_config/base_configuration/system/helpers/fix-steam-bwrap.sh) (symlink patch) remains available but requires re-running after each Steam client update.

## Usage

```bash
# Steam, Flatpak — transparent LD_PRELOAD
bwrap-mount-shim steam
bwrap-mount-shim flatpak run com.example.App

# AppImages, standalone apps — auto-sandbox
bwrap-mount-shim ./YourApp.AppImage

# Explicit bwrap control
bwrap-mount-shim --ro-bind / / --dev /dev --proc /proc --tmpfs /tmp -- ./myapp
```

## Technical Details

### How It Works

1. `mount_shim.so` is loaded via `LD_PRELOAD`
2. It resolves the real `mount()` via `dlsym(RTLD_NEXT, "mount")`
3. When `mount("tmpfs", ...)` is called:
   - Creates a unique directory via `mkdtemp` under `$BWRAP_CACHE_DIR/tmpfs-XXXXXX`
   - Registers the directory for cleanup via `atexit`
   - Redirects to `mount(NULL, target, NULL, MS_BIND, data)`
4. All other mount calls pass through to the real `mount()` unchanged

### Cache Directory

Temp directories are created under:
```
${BWRAP_CACHE_DIR:-/tmp/bwrap-cache}/tmpfs-XXXXXXXX
```

Directories are cleaned up on normal process exit via `atexit`. On signal kill or abrupt namespace teardown, cleanup may not run — `/tmp` is cleared on reboot regardless.

### Limitations

- **Performance** — bind mounts may have slightly different characteristics than tmpfs
- **Compatibility** — some applications may expect true tmpfs behavior (e.g., size limits via `--tmpfs-size`)
- **Cleanup** — `atexit` is best-effort; directories may persist until reboot on abnormal exit

## Troubleshooting

### bwrap still fails with "Operation not permitted"

1. Check wrappers exist:
   ```bash
   ls -la /run/wrappers/bin/bwrap
   which bwrap-mount-shim
   ```

2. Verify bwrap has SUID permission:
   ```bash
   stat -c '%a %n' /run/wrappers/bin/bwrap
   # Should show 4xxx (SUID bit set)
   ```

3. Test with the shim:
   ```bash
   bwrap-mount-shim bwrap --ro-bind / / --dev /dev --proc /proc --tmpfs /tmp echo "works"
   ```

### Application-specific issues

Some applications bundle their own bwrap. The LD_PRELOAD shim handles these transparently — no per-application configuration needed. If tmpfs calls still fail, verify the shim is loaded:

```bash
LD_PRELOAD=/path/to/mount_shim.so ldd /path/to/app | grep mount_shim
```
