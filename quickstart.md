# NixOS Shimboot Quickstart Guide

> **Warning**: This is a Proof-of-Concept project. It may not work reliably and is intended for experimentation only. See [README.md](README.md) for full details and caveats.

## What is NixOS Shimboot?

NixOS Shimboot allows you to boot a full NixOS system on enterprise-enrolled Chromebooks by repurposing a ChromeOS RMA "shim" as an initial bootloader. This lets you run Linux without unenrolling the device or modifying its firmware.

## Prerequisites

- A compatible Chromebook (supported boards: corsola, dedede, grunt, hana, hatch, jacuzzi, nissa, octopus, snappy, zork)
- ChromeOS RMA shim image for your specific board
- USB drive (at least 16GB recommended)
- NixOS system for building (or any Linux with Nix installed)
- Root access for flashing

## Quick Build and Flash

### 1. Clone and Enter the Repository

```bash
git clone https://github.com/PopCat19/nixos-shimboot.git
cd nixos-shimboot
```

### 2. Build the Complete Shimboot Image

Use the `assemble-final.sh` script to build a complete shimboot image that combines the NixOS rootfs with the ChromeOS shim. Replace `BOARD` with your Chromebook's board name:

```bash
# For dedede board (e.g., HP Chromebook 11 G9 EE) - full image (recommended)
sudo ./assemble-final.sh --board dedede --rootfs full

# For minimal image (base configuration only)
sudo ./assemble-final.sh --board dedede --rootfs minimal

# For other boards, replace 'dedede' with your board name:
# corsola, grunt, hana, hatch, jacuzzi, nissa, octopus, snappy, zork
```

**Options:**
- `--rootfs full`: Full image with Home Manager, LightDM, and Hyprland desktop (recommended)
- `--rootfs minimal`: Minimal image with base configuration and greetd/Hyprland
- `--drivers vendor`: Store ChromeOS drivers on separate vendor partition (default)
- `--drivers inject`: Inject drivers directly into the rootfs
- `--drivers none`: Skip driver harvesting
- `--inspect`: Inspect the final image after building

The script will:
- Build the NixOS rootfs and ChromeOS components
- Harvest ChromeOS drivers and firmware
- Create a partitioned image at `work/shimboot.img`
- Populate all partitions with the bootloader, rootfs, and drivers

### 3. Flash to USB Drive

**⚠️ WARNING: This will overwrite the target device. Double-check your device selection!**

First, list available devices to identify your USB drive:

```bash
sudo ./write-shimboot-image.sh --list
```

Flash the assembled image to your USB drive (replace `/dev/sdX` with your actual USB device path):

```bash
sudo ./write-shimboot-image.sh -i "$(pwd)/work/shimboot.img" --output /dev/sdX
```

The assembled image is ready to flash and already contains everything needed for your board.

### 5. Boot Your Chromebook

1. Insert the prepared USB drive into your Chromebook
2. Enter recovery mode (usually Esc + Refresh + Power, or check your specific model's key combination)
3. Select the "shimboot" option from the recovery menu
4. The system should boot into NixOS with the LightDM greeter

## First Boot

- Root user: `root` (password: `nixos-shimboot`)
- Default user: `nixos-user` (password: `nixos-shimboot`)
- Desktop: Hyprland with basic configuration
- Network: Should work out of the box
- Firefox: Available via `nix-shell -p firefox`

## Troubleshooting

### Build Issues
- If you get impure errors, try: `nix build --impure`
- Ensure you're using the correct board name (case-sensitive): corsola, dedede, grunt, hana, hatch, jacuzzi, nissa, octopus, snappy, zork
- For ChromeOS artifacts, ensure you have the correct board manifest

### Boot Issues
- Verify your Chromebook board is in the supported list above
- Confirm the shim image matches your exact device model
- Try the minimal image if the full image fails: `nix build .#raw-rootfs-minimal-BOARD`
- Check that recovery mode key combination is correct for your model

### Space Issues
- The default image is ~8GB; ensure your USB drive has enough space
- Use `nix-shell` for additional packages to save space
- Consider the minimal image for devices with limited storage

## Next Steps

- Customize the system configuration in `shimboot_config/`
- Add your own Home Manager configuration
- Experiment with different desktop environments
- Contribute bug reports or improvements

## Known Limitations

- Currently only tested on HP Chromebook 11 G9 EE ("dedede" board) as of writing
- Multi-board support infrastructure exists but requires testing on other models
- No suspend support (ChromeOS kernel limitation)
- Limited audio support
- Requires `--impure` for some builds
- May require manual kernel namespace workarounds for `nixos-rebuild`

For full documentation, see [README.md](README.md).