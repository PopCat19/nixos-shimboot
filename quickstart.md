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
- `--drivers both`: Place drivers in vendor partition AND inject into rootfs
- `--inspect`: Inspect the final image after building
- `--dry-run`: Test build process without making destructive changes
- `--prewarm-cache`: Fetch derivations from Cachix before building
- `--cleanup-rootfs`: Remove old shimboot rootfs generations after build
- `--cleanup-keep N`: Keep last N generations during cleanup (default: 3)
- `--no-dry-run`: Actually delete files during cleanup (default: dry-run)
- `--fresh`: Start build from beginning, ignoring any checkpoints

The script will:
- Verify Cachix cache configuration and connectivity
- Build Nix outputs with retry logic and CI optimization
- Harvest ChromeOS drivers and firmware with upstream augmentation
- Create partitioned image at `work/shimboot.img`
- Populate all partitions with bootloader, rootfs, and drivers
- Generate build metadata at `/etc/shimboot-build.json`
- Optionally push built derivations to Cachix cache

### 3. Flash to USB Drive

**⚠️ WARNING: This will overwrite the target device. Double-check your device selection!**

List available devices to identify your USB drive:

```bash
sudo ./write-shimboot-image.sh --list
```

Interactive device selection with safety validation:

```bash
sudo ./write-shimboot-image.sh -i "$(pwd)/work/shimboot.img"
```

Direct device targeting with safety checks:

```bash
sudo ./write-shimboot-image.sh -i "$(pwd)/work/shimboot.img" --output /dev/sdX
```

**Safety Features:**
- Automatic system disk detection and exclusion
- Interactive confirmation with countdown timer
- Automatic unmounting of target device partitions
- Size validation and large device warnings
- Dry-run mode for testing: `--dry-run`

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

### "Git fetch failed" during setup_nixos
The git remote may be pointing to the build machine's path. Fix with:
```bash
cd ~/nixos-config
git remote set-url origin https://github.com/PopCat19/nixos-shimboot.git
git fetch origin
```

### "blockdev: Unknown command" during expand_rootfs
Run the script with DEBUG=1 to see what's failing:
```bash
sudo DEBUG=1 expand_rootfs
```

If it still fails, manually expand:
```bash
sudo growpart /dev/sdX N  # Replace X and N with your disk/partition
sudo resize2fs /dev/sdXN
```

### Build Issues
- If you get impure errors, try: `nix build --impure`
- Ensure you're using the correct board name (case-sensitive): dedede, grunt, hatch, nissa, octopus, snappy, zork
- For ChromeOS artifacts, ensure you have the correct board manifest
- Check cache health before building: `./tools/check-cachix.sh dedede`
- Use `--dry-run` to test the build process without destructive operations
- Enable cache pre-warming: `--prewarm-cache` to fetch derivations before building

### Cache Management
- Built-in Cachix integration for faster builds
- Check cache coverage: `./tools/check-cachix.sh [BOARD]`
- Cache automatically configured in Nix settings
- Push built derivations to cache for faster subsequent builds

### Boot Issues
- Verify your Chromebook board is in the supported list above
- Confirm the shim image matches your exact device model
- Try the minimal image if the full image fails: `sudo ./assemble-final.sh --board BOARD --rootfs minimal`
- Check that recovery mode key combination is correct for your model
- Inspect build metadata: `cat /etc/shimboot-build.json` on the running system

### Space Issues
- Ensure `sudo expand_rootfs` succeeded in allocating rootfs to full USB space
- The default minimal/base image is ~6-8GB (expandable); ensure your USB drive has enough space
- Use `--cleanup-rootfs` to remove old generations and free space
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
- May require manual kernel namespace workarounds for `nixos-rebuild` (e.g. appending `--option sandbox false` on shim kernels <5.6)

For more documentation, see [README.md](README.md) and [SPEC.md](SPEC.md).
