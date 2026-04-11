# Bwrap LSM Workaround - Quick Reference

## Problem

ChromeOS LSM blocks tmpfs mounts, causing:
```
bwrap: Failed to mount tmpfs: Operation not permitted
```

## Solution

Use `bwrap-safe` wrapper that converts tmpfs to bind mounts.

## Quick Commands

### Setup (Run Once)

```bash
setup-bwrap-workaround
```

### For AppImages

```bash
# Using system wrapper
/run/wrappers/bin/bwrap-safe --ro-bind / / --dev /dev --proc /proc --tmpfs /tmp ./YourApp.AppImage

# Using helper script
bwrap-lsm-workaround --ro-bind / / --dev /dev --proc /proc --tmpfs /tmp ./YourApp.AppImage
```

### For Steam

```bash
# Fix Steam's internal bwrap
fix-steam-bwrap

# Then launch Steam normally
steam
```

### Test bwrap

```bash
# Basic test
bwrap-safe --ro-bind / / --dev /dev --proc /proc echo "test"

# Tmpfs test
bwrap-safe --ro-bind / / --dev /dev --proc /proc --tmpfs /tmp echo "tmpfs test"
```

## Available Commands

- `bwrap-safe` - SUID wrapper that converts tmpfs to bind mounts
- `bwrap-lsm-workaround` - Standalone wrapper script
- `setup-bwrap-workaround` - Interactive setup script
- `fix-steam-bwrap` - Fix Steam's internal bwrap

## Cache Directory

Location: `${XDG_RUNTIME_DIR}/bwrap-cache`

- Created automatically
- Cleaned on reboot
- Unique per user

## Documentation

- Full documentation: [`docs/BWRAP-LSM-WORKAROUND.md`](BWRAP-LSM-WORKAROUND.md)

## Troubleshooting

### bwrap still fails

1. Check if wrapper exists:
   ```bash
   ls -la /run/wrappers/bin/bwrap-safe
   ```

2. Test basic bwrap:
   ```bash
   bwrap --ro-bind / / --dev /dev --proc /proc echo "test"
   ```

3. Run setup script:
   ```bash
   setup-bwrap-workaround
   ```

### Cache directory issues

```bash
# Manually create cache directory
mkdir -p "${XDG_RUNTIME_DIR}/bwrap-cache"
chmod 700 "${XDG_RUNTIME_DIR}/bwrap-cache"
```

## Notes

- The workaround converts tmpfs mounts to bind mounts
- This maintains sandboxing while avoiding ChromeOS LSM restrictions
- Cache directories are cleaned on reboot
- Some applications may need manual configuration
