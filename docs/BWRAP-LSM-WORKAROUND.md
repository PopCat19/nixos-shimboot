# Bwrap LSM Workaround for ChromeOS Shimboot

## Overview

ChromeOS's security model includes a Linux Security Module (LSM) called `chromiumos` that restricts certain operations, including mounting tmpfs filesystems. This causes issues with `bwrap` (bubblewrap), which is commonly used for sandboxing applications like Steam, AppImages, and various Nix packages.

## Problem

When applications try to use `bwrap` with tmpfs mounts, they encounter:

```
bwrap: Failed to mount tmpfs: Operation not permitted
```

This occurs because the ChromeOS LSM blocks tmpfs mounts even when running as root or with SUID permissions.

## Solution

The workaround converts tmpfs mounts to bind mounts, which are allowed by the ChromeOS LSM. This is implemented through:

1. **SUID bwrap wrapper** - Provides namespace creation capabilities
2. **bwrap-safe wrapper** - Converts tmpfs mounts to bind mounts
3. **Helper scripts** - Simplify setup and usage

## Implementation

### Security Configuration

The [`security.nix`](../shimboot_config/base_configuration/system/security.nix) module creates two SUID wrappers:

- `bwrap` - Standard SUID wrapper for namespace creation
- `bwrap-safe` - Wrapper that converts tmpfs to bind mounts

### Helper Scripts

#### bwrap-lsm-workaround.sh

A standalone script that can be used as a drop-in replacement for bwrap. It intercepts `--tmpfs` arguments and converts them to bind mounts using a cache directory.

**Usage:**
```bash
bwrap-lsm-workaround --ro-bind / / --dev /dev --proc /proc --tmpfs /tmp ./app.AppImage
```

#### setup-bwrap-workaround.sh

Interactive script that:
- Creates bwrap cache directory with proper permissions
- Tests bwrap functionality
- Creates user-local wrappers
- Provides usage instructions

**Usage:**
```bash
setup-bwrap-workaround
```

#### fix-steam-bwrap.sh

Patches Steam's internal bwrap (`srt-bwrap`) with the system bwrap-safe wrapper.

**Usage:**
```bash
fix-steam-bwrap
```

## Usage Examples

### For AppImages

```bash
# Using the system wrapper
/run/wrappers/bin/bwrap-safe --ro-bind / / --dev /dev --proc /proc --tmpfs /tmp ./YourApp.AppImage

# Using the helper script
bwrap-lsm-workaround --ro-bind / / --dev /dev --proc /proc --tmpfs /tmp ./YourApp.AppImage
```

### For Nix Packages

Many Nix packages that use bwrap internally will automatically benefit from the bwrap-safe wrapper if it's in the system PATH.

### For Steam

```bash
# Run the fix script (only needed once per Steam installation)
fix-steam-bwrap

# Then launch Steam normally
steam
```

### Manual bwrap Usage

```bash
# Test basic functionality
bwrap-safe --ro-bind / / --dev /dev --proc /proc echo "test"

# Test tmpfs workaround
bwrap-safe --ro-bind / / --dev /dev --proc /proc --tmpfs /tmp echo "tmpfs test"
```

## Technical Details

### How It Works

1. The `bwrap-safe` wrapper intercepts bwrap command-line arguments
2. When it encounters `--tmpfs`, it:
   - Creates a unique directory in the cache directory
   - Sets permissions to 700 (user-only access)
   - Replaces `--tmpfs` with `--bind` pointing to the cache directory
3. Executes the real bwrap with modified arguments

### Cache Directory

The bwrap cache directory is located at:
```
${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/bwrap-cache
```

This directory is:
- Created automatically with proper permissions
- Unique per user
- Cleaned up on reboot (located in runtime directory)

### Limitations

1. **Performance** - Bind mounts may have slightly different performance characteristics than tmpfs
2. **Disk space** - Cache directories consume disk space (cleaned on reboot)
3. **Compatibility** - Some applications may expect true tmpfs behavior

## Troubleshooting

### bwrap still fails with "Operation not permitted"

1. Check if bwrap-safe wrapper exists:
   ```bash
   ls -la /run/wrappers/bin/bwrap-safe
   ```

2. Verify SUID permissions:
   ```bash
   ls -la /run/wrappers/bin/bwrap
   ```

3. Test basic bwrap functionality:
   ```bash
   bwrap --ro-bind / / --dev /dev --proc /proc echo "test"
   ```

### Cache directory issues

1. Check cache directory permissions:
   ```bash
   ls -la "${XDG_RUNTIME_DIR}/bwrap-cache"
   ```

2. Manually create cache directory:
   ```bash
   mkdir -p "${XDG_RUNTIME_DIR}/bwrap-cache"
   chmod 700 "${XDG_RUNTIME_DIR}/bwrap-cache"
   ```

### Application-specific issues

Some applications may have their own bwrap configurations. In these cases:

1. Check if the application has a bwrap configuration file
2. Modify it to use `bwrap-safe` instead of `bwrap`
3. Or set up a wrapper script for the application

## References

- [ChromeOS Security Model](https://www.chromium.org/chromium-os/chromiumos-design-docs/security-overview/)
- [Bubblewrap Documentation](https://github.com/containers/bubblewrap)
- [NixOS Security Wrappers](https://nixos.org/manual/nixos/stable/#sec-security-wrappers)

## Related Files

- [`security.nix`](../shimboot_config/base_configuration/system/security.nix) - Security wrapper configuration
- [`bwrap-lsm-workaround.sh`](../shimboot_config/base_configuration/system/helpers/bwrap-lsm-workaround.sh) - Standalone wrapper script
- [`setup-bwrap-workaround.sh`](../shimboot_config/base_configuration/system/helpers/setup-bwrap-workaround.sh) - Setup helper
- [`fix-steam-bwrap.sh`](../shimboot_config/base_configuration/system/helpers/fix-steam-bwrap.sh) - Steam-specific fix
