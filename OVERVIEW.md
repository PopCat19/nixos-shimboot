# NixOS Shimboot

Boot NixOS on locked ChromeOS devices using the RMA shim vulnerability.

## Quick Links

- [Quickstart Guide](QUICKSTART.md) - Build and flash instructions
- [README.md](README.md) - Project background and progress tracking

## Architecture

```
ChromeOS Firmware → Shim Kernel (patched) → Bootloader → NixOS
```

Shimboot exports `nixosModules.chromeos`. . A hardware abstraction layer for ChromeOS devices. External flakes import it as a module and layer personal configuration on top.

## Configuration

| Path | Purpose |
|------|---------|
| `shimboot_config/user-config.nix` | Shared variables (hostname, username, theme) |
| `shimboot_config/base_configuration/` | ChromeOS base system (boot, fs, hw, users) |

## Build

```bash
sudo ./tools/build/assemble-final.sh --board <board> --rootfs minimal
```

Supported boards: dedede, octopus, zork, nissa, hatch, grunt, snappy

## Desktop Configuration

Personal configs live in a companion repo: [nixos-shimboot-config](https://github.com/PopCat19/nixos-shimboot-config)

```nix
# In your flake:
inputs.shimboot.url = "github:PopCat19/nixos-shimboot/dev";

modules = [
  shimboot.nixosModules.chromeos    # ChromeOS HAL
  ./my-config.nix                    # personal config
];
```

## Known Limitations

- **Systemd ceiling: 257.x** — boards with older shim kernels cannot run systemd 258+ due to missing `open_tree()`/`move_mount()` syscalls (kernel <5.10). See [shimboot#405](https://github.com/ading2210/shimboot/issues/405).
- No suspend support (kernel limitation)
- Limited audio support
- `nixos-rebuild` may require `--option sandbox false` on kernels <5.6

## Board Kernel Versions

Extracted from ChromeOS recovery images. Determines systemd compatibility.

| Board | ChromeOS Version | Kernel Version | systemd ≥258? |
|-------|------------------|----------------|----------------|
| snappy | 9334.72.0 | 4.4.35 | ❌ Needs 257.x |
| grunt | 11151.113.0 | 4.14.75 | ❌ Needs 257.x |
| octopus | 11316.165.0 | 4.14.91 | ❌ Needs 257.x |
| hatch | 12739.94.0 | 4.19.84 | ❌ Needs 257.x |
| dedede | 13597.105.0 | 5.4.85 | ⚠️ Border (5.4 < 5.10) |
| zork | 13505.73.0 | 5.4.85 | ⚠️ Border (5.4 < 5.10) |
| nissa | 15236.80.0 | 5.15.74 | ✅ Can use 258+ |

**Note:** dedede and zork (5.4.x kernels) are below 5.10 threshold. Recommend systemd 257.x for all boards until confirmed otherwise.
