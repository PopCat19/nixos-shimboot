# NixOS Shimboot Quickstart Guide

> **Warning**: This is a Proof-of-Concept project. It may not work reliably and is intended for experimentation only. See [README.md](README.md) for full details and caveats.

## What is NixOS Shimboot?

NixOS Shimboot allows you to boot a full NixOS system on enterprise-enrolled Chromebooks by repurposing a ChromeOS RMA "shim" as an initial bootloader. This lets you run Linux without unenrolling the device or modifying its firmware.

## Prerequisites

- A compatible Chromebook (supported boards: dedede, octopus, zork, nissa, hatch, grunt, snappy)
- ChromeOS RMA shim image for your specific board
- USB drive (at least 32GB recommended)
- NixOS system for building (or any Linux with Nix installed)
- Root access for flashing

## Quick Build and Flash

### 1. Clone and Enter the Repository

```bash
git clone https://github.com/PopCat19/nixos-shimboot.git
cd nixos-shimboot
```

### 2. Build the Complete Shimboot Image

Use the `assemble-final.sh` script (will require sudo/root for mount loops) to build a complete shimboot image that combines the NixOS rootfs with the ChromeOS shim. Replace `BOARD` with your Chromebook's board name:

```bash
# For dedede board (e.g., HP Chromebook 11 G9 EE) - full image (recommended)
sudo ./assemble-final.sh --board dedede --rootfs full

# For minimal image (base configuration only; useful for testing critical configurations)
sudo ./assemble-final.sh --board dedede --rootfs minimal

# For other boards, replace 'dedede' with your board name:
# grunt, hatch, nissa, octopus, snappy, zork
```

**Options:**
- `--rootfs full`: Full image with Home Manager, LightDM, and Hyprland desktop (recommended)
- `--rootfs minimal`: Minimal image with base configuration and LightDM/Hyprland
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

List available devices to identify your USB drive:

```bash
sudo ./write-shimboot-image.sh --list
```

Flash the assembled image to your USB drive (replace `/dev/sdX` with your actual USB device path):

```bash
sudo ./write-shimboot-image.sh -i "$(pwd)/work/shimboot.img" --output /dev/sdX
```

The assembled image is ready to flash and already contains everything needed for your board.

### 4. Boot Your Chromebook

1. Insert the prepared USB drive into your Chromebook
2. Enter recovery mode (usually Esc + Refresh + Power, or check your specific model's key combination)
3. Select the "shimboot" option from the recovery menu
4. The system should boot into NixOS with the LightDM greeter

## First Boot (for minimal/base configuration)

- Root user: `root` (initial password: `nixos-shimboot`)
- Default user: `nixos-user` (initial password: `nixos-shimboot`)
- Desktop: LightDM + Hyprland (default config)
- Network: NetworkManager with wpa_supplicant backend
    - WiFi should work out of the box if vendor drivers are available
    - Configure with `nmtui` or execute `setup_nixos` helper

## Troubleshooting

### Build Issues
- If you get impure errors, try: `nix build --impure`
- Ensure you're using the correct board name (case-sensitive): dedede, grunt, hatch, nissa, octopus, snappy, zork
- For ChromeOS artifacts, ensure you have the correct board manifest

### Boot Issues
- Verify your Chromebook board is in the supported list above
- Confirm the shim image matches your exact device model
- Try the minimal image if the full image fails: `sudo ./assemble-final.sh --board BOARD --rootfs minimal`
- Check that recovery mode key combination is correct for your model

### Space Issues
- Ensure `sudo expand_rootfs` succeeded in allocating rootfs to full USB space
- The default minimal/base image is ~6-8GB (expandable); ensure your USB drive has enough space
- Use `nix-shell` for temporary packages to save space
- Consider the minimal image for devices with limited storage (you can also create your own custom main_configuration port if you'd prefer c:)

## Next Steps

- Customize the system configuration in `shimboot_config/`
- Add your own Home Manager configuration
- Experiment with different desktop environments
- Contribute bug reports or improvements

## Known Limitations

- Currently only tested on HP Chromebook 11 G9 EE ("dedede" board)
- Multi-board support infrastructure exists but requires testing on other models
- No suspend support (ChromeOS kernel limitation)
- Limited audio support
- May require `--impure` for some builds
- May require manual kernel namespace workarounds for `nixos-rebuild` (e.g. appending `--options disable sandbox` on shim kernels <5.6)

For more documentation, see [README.md](README.md) and [SPEC.md](SPEC.md).
