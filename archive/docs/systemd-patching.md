# Systemd Patching for Shimboot

## Overview

The shimboot project requires a patched version of systemd to function correctly. This patch modifies the `mount_nofollow()` function to allow proper mounting behavior in the ChromeOS environment.

## The Patch

The patch is located at `nix/patches/systemd_unstable.patch` and modifies the `mount_nofollow()` function in `src/basic/mountpoint-util.c`:

```diff
- return mount_fd(source, fd, filesystemtype, mountflags, data);
+ return RET_NERRNO(mount(source, target, filesystemtype, mountflags, data));
```

This change simplifies the mount operation to work correctly in the shimboot environment.

## Default Configuration

The build script is now configured to use a specific, tested systemd binary that has been verified to work correctly:

- **Systemd version**: 257.6
- **Binary path**: `/nix/store/31v77wh2wsmn44sqayd4f34rxh94d459-systemd-257.6/lib/systemd/systemd`

This configuration ensures reproducible builds and prevents issues from systemd updates.

## Build Script Integration

The build script (`scripts/build-final-image.sh`) includes several features to ensure the correct systemd is used:

### 1. Patch Verification

The script automatically verifies that the selected systemd binary contains the required patch by checking for:
- The presence of the `mount_nofollow` function
- The use of the `RET_NERRNO` macro
- The simplified mount call implementation

### 2. Version Locking

The script is locked to systemd version 257.6 for stability. You can override this:

```bash
./scripts/build-final-image.sh --systemd-version 257.6
```

### 3. Manual Binary Specification

You can specify a different systemd binary path if needed:

```bash
./scripts/build-final-image.sh --systemd-binary-path /path/to/systemd
```

### 4. Patch Requirement

By default, the build will fail if no patched systemd is found. You can disable this requirement (not recommended):

```bash
./scripts/build-final-image.sh --no-require-patched-systemd
```

## Configuration

### NixOS Configuration

Ensure your NixOS configuration includes the systemd patch:

```nix
# system_modules/systemd.nix
{
  systemd = {
    package = pkgs.systemd.overrideAttrs (old: {
      patches = (old.patches or []) ++
        [ ../nix/patches/systemd_unstable.patch ];
    });
  };
}
```

### Overlay Configuration

The overlay configuration in `nix/overlay.nix` also applies the patch:

```nix
# nix/overlay.nix
(final: prev: {
  systemd = prev.systemd.overrideAttrs (oldAttrs: {
    patches = (oldAttrs.patches or []) ++ [
      ../nix/patches/systemd_unstable.patch
    ];
  });
})
```

## Troubleshooting

### "No patched systemd binary found"

This error occurs when the build script cannot find a systemd binary that contains the required patch. To resolve:

1. **Verify the patch is applied**: Check that your NixOS configuration includes the systemd patch
2. **Rebuild the system**: Run `nixos-rebuild switch` to apply the patch
3. **Check the systemd version**: Use `--systemd-version` to specify the exact version you expect

### "Systemd version X does not match required version Y"

This error occurs when version locking is enabled but the expected version is not found. To resolve:

1. **Check available versions**: The build script will log available systemd binaries
2. **Update the version**: Use the correct version with `--systemd-version`
3. **Remove version locking**: Remove the `--systemd-version` argument if you don't need to lock to a specific version

### Verification

To verify that a build is using the correct systemd:

1. **Check the build log**: The build script logs which systemd binary was selected
2. **Inspect the final image**: Mount the image and check the `/init` symlink
3. **Check the systemd binary**: Use `strings` on the systemd binary to verify the patch is applied

## Best Practices

1. **Always use patched systemd**: The `--no-require-patched-systemd` option should only be used for testing
2. **Lock to a specific version**: For production builds, use `--systemd-version` to ensure reproducible builds
3. **Keep the patch updated**: Monitor systemd updates and ensure the patch remains compatible
4. **Test thoroughly**: Always test the built image to ensure it boots correctly

## Known Working Configuration

The following systemd configuration has been tested and verified to work:

- **Version**: 257.6
- **Store hash**: `31v77wh2wsmn44sqayd4f34rxh94d459`
- **Full path**: `/nix/store/31v77wh2wsmn44sqayd4f34rxh94d459-systemd-257.6/lib/systemd/systemd`

This is now the default configuration used by the build script.

## Future Considerations

As systemd evolves, the patch may need to be updated. Consider:

1. **Version locking**: Lock to a specific systemd commit for long-term stability
2. **Patch maintenance**: Monitor systemd changes that may affect the patch
3. **Alternative approaches**: Evaluate if the patch can be replaced with configuration changes in future systemd versions