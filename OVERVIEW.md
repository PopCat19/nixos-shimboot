# NixOS Shimboot

Boot NixOS on locked ChromeOS devices using the RMA shim vulnerability.

## Quick Links

- [Quickstart Guide](QUICKSTART.md) - Build and flash instructions
- [README.md](README.md) - Project background and progress tracking

## Architecture

```
ChromeOS Firmware → Shim Kernel (patched) → Bootloader → NixOS
```

## Configuration

| Path | Purpose |
|------|---------|
| `shimboot_config/user-config.nix` | User variables (username, hostname) |
| `shimboot_config/main_configuration/` | Desktop environment |
| `shimboot_config/base_configuration/` | Minimal bootable system |

## Build

```bash
sudo ./assemble-final.sh --board <board> --rootfs full
```

Supported boards: dedede, octopus, zork, nissa, hatch, grunt, snappy

## Known Limitations

- No suspend support (kernel limitation)
- Limited audio support
- `nixos-rebuild` may require `--option sandbox false` on kernels <5.6
