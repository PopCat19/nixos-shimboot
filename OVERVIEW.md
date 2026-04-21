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

- **Systemd ceiling: 257.x** — boards with older shim kernels (octopus 4.14.x) cannot run systemd 258+ due to missing `open_tree()`/`move_mount()` syscalls. See [shimboot#405](https://github.com/ading2210/shimboot/issues/405).
- No suspend support (kernel limitation)
- Limited audio support
- `nixos-rebuild` may require `--option sandbox false` on kernels <5.6
