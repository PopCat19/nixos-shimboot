## Overview

ChromeOS’s security model includes a Linux Security Module (LSM) called `chromiumos` that restricts certain operations, including mounting tmpfs filesystems.

This causes issues with `bwrap` (bubblewrap), which is commonly used for sandboxing applications like Steam, AppImages, and various Nix packages.

## Problem

When applications try to use `bwrap` with tmpfs mounts, they encounter:

```
bwrap: Failed to mount tmpfs: Operation not permitted
```

This occurs because the ChromeOS LSM blocks tmpfs mounts even when running as root or with SUID permissions.

## Solution

On dedede (kernel 5.4.85), SUID bwrap alone handles tmpfs, the `chromiumos`
LSM does not block `mount("tmpfs", ...)` when running as root via
`security.wrappers.bwrap`. No additional workaround is needed for basic bwrap
sandboxing.

For boards where the LSM blocks tmpfs despite SUID (unconfirmed for any board
so far), `bwrap-mount-shim` provides an LD_PRELOAD-based fallback that
intercepts `mount()` at the libc level and converts tmpfs to bind mounts.

Flatpak on kernel 5.4 has a separate incompatibility: `flatpak run` uses
`statx` with fields not available until kernel 5.8, producing `ENODATA`.
As a workaround, `bwrap-mount-shim --sandbox` or direct bwrap invocation can
launch flatpak apps bypassing flatpak's sandbox setup.

### Usage

```bash
# SUID bwrap, works on dedede without any shim
bwrap --ro-bind / / --dev /dev --proc /proc --tmpfs /tmp -- ./myapp

# bwrap-mount-shim, optional LD_PRELOAD fallback
bwrap-mount-shim steam                    # LD_PRELOAD only
bwrap-mount-shim --sandbox ./myapp        # LD_PRELOAD + bwrap sandbox

# Flatpak apps, bypass flatpak's broken sandbox on 5.4
bwrap-mount-shim --sandbox -- \
  /var/lib/flatpak/app/.../files/bin/app
```

## Implementation

### Security Configuration

The [`security.nix`](shimboot_config/base_configuration/system/security.nix) module provides:

- `bwrap`, SUID wrapper for namespace creation (ChromeOS kernels restrict unprivileged user namespaces)
- `bwrap-mount-shim`, LD_PRELOAD shim compiled from [`mount_shim.c`](patches/bwrap-mount-shim.c), plus a convenience wrapper script

The C shim intercepts `mount("tmpfs", ...)` calls, creates a unique directory via `mkdtemp` under `$BWRAP_CACHE_DIR` (default: `/tmp/bwrap-cache`), and converts the call to `mount("bind", ...)`. Created directories are cleaned up on normal exit via `atexit`.

### Steam Integration

Steam compatibility is unverified on shimboot hardware. On Debian-based
shimboot (upstream), Steam works with SUID bwrap alone ([shimboot#26](https://github.com/ading2210/shimboot/issues/26)).
If the ChromeOS LSM blocks tmpfs on a given board, `bwrap-mount-shim steam`
can be used as a fallback, the LD_PRELOAD shim intercepts `mount()` inside
`pressure-vessel` without any symlink patching or per-update maintenance.

The legacy [`fix-steam-bwrap.sh`](shimboot_config/base_configuration/system/helpers/fix-steam-bwrap.sh)
(symlink patch) remains available but rots on Steam client updates.

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

Directories are cleaned up on normal process exit via `atexit`. On signal kill or abrupt namespace teardown, cleanup may not run, `/tmp` is cleared on reboot regardless.

### Limitations

- **Performance**, bind mounts may have slightly different characteristics than tmpfs
- **Compatibility**, some applications may expect true tmpfs behavior (e.g., size limits via `--tmpfs-size`)
- **Cleanup**, `atexit` is best-effort; directories may persist until reboot on abnormal exit

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

Some applications bundle their own bwrap. The LD_PRELOAD shim handles these transparently, no per-application configuration needed. If tmpfs calls still fail, verify the shim is loaded:

```bash
LD_PRELOAD=/path/to/mount_shim.so ldd /path/to/app | grep mount_shim
```
