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

The workaround converts tmpfs mounts to bind mounts, which are allowed by the ChromeOS LSM. A single self-contained wrapper, `bwrap-safe`, intercepts `--tmpfs` arguments, replaces each with a `--bind` to a `mktemp`-created directory, then execs the real SUID bwrap.

The design follows the `proxify` pattern — explicit, self-contained, no side effects beyond the invocation:

```bash
bwrap-safe --ro-bind / / --dev /dev --proc /proc --tmpfs /tmp -- ./myprogram
```

## Implementation

### Security Configuration

The [`security.nix`](shimboot_config/base_configuration/system/security.nix) module creates two wrappers:

- `bwrap` — SUID wrapper for namespace creation (ChromeOS kernels restrict unprivileged user namespaces)
- `bwrap-safe` — argument-rewriting wrapper (no SUID needed; the real bwrap handles elevation)

The `bwrap-safe` wrapper:

1. Creates a per-invocation unique directory via `mktemp -d` for each `--tmpfs` mount
2. Replaces `--tmpfs DIR` / `--tmpfs=DIR` with `--bind <mktemp-dir>`
3. Sets a `trap EXIT` to remove all created directories when bwrap finishes
4. Execs the real SUID `/run/wrappers/bin/bwrap` with the transformed arguments

No global PATH manipulation or setup scripts are needed — `bwrap-safe` is a transparent drop-in prefix.

### Steam Integration

Steam's pressure-vessel runtime uses an internal `srt-bwrap` binary. The [`fix-steam-bwrap.sh`](shimboot_config/base_configuration/system/helpers/fix-steam-bwrap.sh) script replaces it with a symlink to `/run/wrappers/bin/bwrap-safe`.

Note: Steam client updates re-download `srt-bwrap`, clobbering the symlink. Re-run the fix script after each Steam update.

## Usage

```bash
# AppImages and Nix packages — prefix with bwrap-safe
bwrap-safe --ro-bind / / --dev /dev --proc /proc --tmpfs /tmp ./YourApp.AppImage

# Steam — one-time patch (re-run after Steam updates)
fix-steam-bwrap
steam

# Test basic functionality
bwrap-safe --ro-bind / / --dev /dev --proc /proc echo "works"

# Test tmpfs workaround (should not error)
bwrap-safe --ro-bind / / --dev /dev --proc /proc --tmpfs /tmp echo "tmpfs ok"
```

## Technical Details

### How It Works

1. The `bwrap-safe` wrapper intercepts command-line arguments
2. When it encounters `--tmpfs` (or `--tmpfs=DIR`):
   - Creates a unique directory via `mktemp -d` under `$XDG_RUNTIME_DIR/bwrap-cache/`
   - Sets permissions to 700
   - Replaces the `--tmpfs` argument with `--bind <mktemp-dir>`
3. Registers a `trap EXIT` handler to remove all created directories
4. Execs the real SUID bwrap with the transformed arguments

### Cache Directory

Temp directories are created under:
```
${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/bwrap-cache/tmpfs-XXXXXXXX
```

Per-invocation cleanup via `trap EXIT` means directories are removed as soon as bwrap exits, not just on reboot. The parent `bwrap-cache/` directory itself persists (empty) for the session lifetime.

### Limitations

- **Performance** — bind mounts may have slightly different characteristics than tmpfs
- **Compatibility** — some applications may expect true tmpfs behavior (e.g., size limits via `--tmpfs-size`)
- **`fix-steam-bwrap.sh`** needs re-running after Steam updates

## Troubleshooting

### bwrap still fails with "Operation not permitted"

1. Check wrappers exist:
   ```bash
   ls -la /run/wrappers/bin/bwrap /run/wrappers/bin/bwrap-safe
   ```

2. Verify `bwrap` has SUID permission:
   ```bash
   stat -c '%a %n' /run/wrappers/bin/bwrap
   # Should show 4xxx (SUID bit set)
   ```

3. Test basic functionality:
   ```bash
   bwrap --ro-bind / / --dev /dev --proc /proc echo "test"
   ```

### Application-specific issues

Some applications bundle their own bwrap. For these:

1. Check if the application has a bwrap configuration or environment variable for overriding the binary path
2. Point it at `/run/wrappers/bin/bwrap-safe` instead of the bundled bwrap
3. Steam specifically: run `fix-steam-bwrap` after each client update
