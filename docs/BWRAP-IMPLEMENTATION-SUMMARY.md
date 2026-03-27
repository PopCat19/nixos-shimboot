# Bwrap LSM Workaround Implementation Summary

## Problem Statement

ChromeOS's security model includes a Linux Security Module (LSM) called `chromiumos` that restricts certain operations, including mounting tmpfs filesystems. This causes issues with `bwrap` (bubblewrap), which is commonly used for sandboxing applications like Steam, AppImages, and various Nix packages.

When applications try to use `bwrap` with tmpfs mounts, they encounter:

```
bwrap: Failed to mount tmpfs: Operation not permitted
```

## Root Cause Analysis

### Investigation Results

1. **Kernel Version**: 5.4.85-22138-ga9994f5cad40 (< 5.6, no user namespace support)
2. **LSM Modules Loaded**: capability, yama, loadpin, safesetid, chromiumos, selinux
3. **Mount Restrictions**: `/tmp` is mounted as tmpfs without `noexec`, but ChromeOS LSM blocks tmpfs mounts
4. **SUID Wrapper**: Already configured in [`security.nix`](../shimboot_config/base_configuration/system/security.nix)
5. **Workaround Verified**: Bind mounts work, tmpfs mounts fail

### Key Finding

The ChromeOS LSM (`chromiumos`) specifically blocks tmpfs mount operations even when running as root or with SUID permissions. This is a security feature of ChromeOS that cannot be disabled without modifying the kernel.

## Solution Implemented

### 1. SUID bwrap-safe Wrapper

Created a new SUID wrapper in [`security.nix`](../shimboot_config/base_configuration/system/security.nix) that:
- Intercepts bwrap command-line arguments
- Converts `--tmpfs` mounts to `bind` mounts
- Uses a cache directory for temporary storage
- Maintains sandboxing functionality while avoiding LSM blocks

### 2. Helper Scripts

#### bwrap-lsm-workaround.sh
Standalone script that can be used as a drop-in replacement for bwrap. It:
- Parses bwrap arguments
- Converts `--tmpfs` to `--bind` with cache directories
- Executes the real bwrap with modified arguments

**Location**: [`shimboot_config/base_configuration/system/helpers/bwrap-lsm-workaround.sh`](../shimboot_config/base_configuration/system/helpers/bwrap-lsm-workaround.sh)

#### setup-bwrap-workaround.sh
Interactive setup script that:
- Creates bwrap cache directory with proper permissions
- Tests bwrap functionality
- Creates user-local wrappers
- Provides usage instructions

**Location**: [`shimboot_config/base_configuration/system/helpers/setup-bwrap-workaround.sh`](../shimboot_config/base_configuration/system/helpers/setup-bwrap-workaround.sh)

#### fix-steam-bwrap.sh
Updated to prefer `bwrap-safe` wrapper over regular `bwrap` for Steam compatibility.

**Location**: [`shimboot_config/base_configuration/system/helpers/fix-steam-bwrap.sh`](../shimboot_config/base_configuration/system/helpers/fix-steam-bwrap.sh)

### 3. Test Suite

Created comprehensive test script that verifies:
- Basic bwrap functionality
- Cache directory creation and permissions
- Wrapper availability
- Bind mount functionality

**Location**: [`tests/test-bwrap-workaround.sh`](../tests/test-bwrap-workaround.sh)

### 4. Documentation

Created detailed documentation explaining:
- Problem description and root cause
- Solution implementation details
- Usage examples for various applications
- Troubleshooting guide
- Technical details and limitations

**Location**: [`docs/BWRAP-LSM-WORKAROUND.md`](../docs/BWRAP-LSM-WORKAROUND.md)

## Files Modified

### Configuration Files

1. **[`security.nix`](../shimboot_config/base_configuration/system/security.nix)**
   - Added `bwrap-safe` SUID wrapper
   - Maintains existing `bwrap` wrapper

2. **[`helpers.nix`](../shimboot_config/base_configuration/system/helpers/helpers.nix)**
   - Added `bwrap-lsm-workaround` script
   - Added `setup-bwrap-workaround` script
   - Added dependencies for new scripts

3. **[`fix-steam-bwrap.sh`](../shimboot_config/base_configuration/system/helpers/fix-steam-bwrap.sh)**
   - Updated to prefer `bwrap-safe` wrapper
   - Falls back to regular `bwrap` if needed

### Helper Scripts

1. **[`bwrap-lsm-workaround.sh`](../shimboot_config/base_configuration/system/helpers/bwrap-lsm-workaround.sh)** (NEW)
   - Standalone bwrap wrapper script
   - Converts tmpfs to bind mounts

2. **[`setup-bwrap-workaround.sh`](../shimboot_config/base_configuration/system/helpers/setup-bwrap-workaround.sh)** (NEW)
   - Interactive setup script
   - Tests and configures bwrap workarounds

### Documentation

1. **[`BWRAP-LSM-WORKAROUND.md`](../docs/BWRAP-LSM-WORKAROUND.md)** (NEW)
   - Comprehensive documentation
   - Usage examples and troubleshooting

2. **[`BWRAP-IMPLEMENTATION-SUMMARY.md`](../docs/BWRAP-IMPLEMENTATION-SUMMARY.md)** (NEW)
   - This file - implementation summary

3. **[`README.md`](../README.md)**
   - Updated obstacles section with workaround reference

### Context Files

1. **[`helpers/context.md`](../shimboot_config/base_configuration/system/helpers/context.md)**
   - Added bwrap-lsm-workaround.sh
   - Added setup-bwrap-workaround.sh

2. **[`tests/context.md`](../tests/context.md)**
   - Added test-bwrap-workaround.sh

3. **[`fish-greeting.fish`](../shimboot_config/base_configuration/system/fish_functions/fish-greeting.fish)**
   - Added bwrap helpers to discovery patterns
   - Updated fallback helper list

## Usage Examples

### For AppImages

```bash
# Using the system wrapper
/run/wrappers/bin/bwrap-safe --ro-bind / / --dev /dev --proc /proc --tmpfs /tmp ./YourApp.AppImage

# Using the helper script
bwrap-lsm-workaround --ro-bind / / --dev /dev --proc /proc --tmpfs /tmp ./YourApp.AppImage
```

### For Steam

```bash
# Run the fix script (only needed once per Steam installation)
fix-steam-bwrap

# Then launch Steam normally
steam
```

### For Nix Packages

Many Nix packages that use bwrap internally will automatically benefit from the bwrap-safe wrapper if it's in the system PATH.

### Manual bwrap Usage

```bash
# Test basic functionality
bwrap-safe --ro-bind / / --dev /dev --proc /proc echo "test"

# Test tmpfs workaround
bwrap-safe --ro-bind / / --dev /dev --proc /proc --tmpfs /tmp echo "tmpfs test"
```

## Testing

Run the test suite to verify functionality:

```bash
tests/test-bwrap-workaround.sh
```

Expected output:
- All tests should pass after NixOS configuration is rebuilt
- Some tests will be skipped if bwrap-safe wrapper is not yet available

## Next Steps

### After Rebuilding NixOS Configuration

1. Run the setup script:
   ```bash
   setup-bwrap-workaround
   ```

2. Test bwrap functionality:
   ```bash
   bwrap-safe --ro-bind / / --dev /dev --proc /proc --tmpfs /tmp echo "test"
   ```

3. Fix Steam if needed:
   ```bash
   fix-steam-bwrap
   ```

### For Applications That Don't Work

If an application still fails with bwrap errors:

1. Check if it has its own bwrap configuration
2. Modify it to use `bwrap-safe` instead of `bwrap`
3. Or create a wrapper script for the application

## Limitations

1. **Performance**: Bind mounts may have slightly different performance characteristics than tmpfs
2. **Disk Space**: Cache directories consume disk space (cleaned on reboot)
3. **Compatibility**: Some applications may expect true tmpfs behavior
4. **Manual Intervention**: Some applications may need manual configuration

## References

- [ChromeOS Security Model](https://www.chromium.org/chromium-os/chromiumos-design-docs/security-overview/)
- [Bubblewrap Documentation](https://github.com/containers/bubblewrap)
- [NixOS Security Wrappers](https://nixos.org/manual/nixos/stable/#sec-security-wrappers)

## Conclusion

The bwrap LSM workaround has been successfully implemented with:
- ✅ SUID bwrap-safe wrapper that converts tmpfs to bind mounts
- ✅ Helper scripts for setup and usage
- ✅ Comprehensive documentation
- ✅ Test suite for verification
- ✅ Integration with existing Steam fix

The solution maintains sandboxing functionality while working around ChromeOS LSM restrictions on tmpfs mounts.
