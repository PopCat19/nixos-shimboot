## Prerequisites

- A compatible Chromebook (Intel: dedede, octopus, nissa, hatch, snappy; AMD: zork, grunt)
- ChromeOS RMA shim image for your specific board
- USB drive with at least 16GB, recommended ≥32GB
- NixOS system or any Linux with Nix installed for building the image
- Root/wheel access for loop mounts and imaging (could work inside docker/WSL2 container, but untested)

## Quick Build and Flash

### 1. Clone and Enter the Repository

```bash
git clone https://github.com/PopCat19/nixos-shimboot.git
cd nixos-shimboot
```

### 2. Build the Shimboot Image

Use the `tools/build/assemble-final.sh` script to build a shimboot image that combines the NixOS rootfs with the ChromeOS shim. Replace `BOARD` with your Chromebook's board name:

```bash
# For dedede board (e.g., HP Chromebook 11 G9 EE) - base image
sudo ./tools/build/assemble-final.sh --board dedede --rootfs base

# For other boards, replace 'dedede' with your board name:
# grunt, hatch, nissa, octopus, snappy, zork
```

**Options:**
- `--rootfs base`: Base image with system configuration (headless also available)
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

### 3. Flash to USB Drive / SD Card

**WARNING: This will overwrite the target device.**

Interactive device selection with predefined image input:
```bash
sudo ./tools/write/write-shimboot-image.sh
```

Afterwards, the imaged usb/sd is ready to boot.

### 4. Boot Your Chromebook

1. Insert the prepared USB drive into your Chromebook
2. Enter recovery mode (Esc + Refresh + Power)
- If not already, enable Developer Mode via Ctrl+D and confirm, then enter recovery mode again
3. Select the "shimboot" option from the recovery menu
4. The system should boot into NixOS with the LightDM greeter

## First Boot (base configuration)

- Root user: `root` (initial password: `nixos-shimboot`)
- Default user: username defined in your profile's `user-config.nix` (default: `nixos-user`, initial password: `nixos-shimboot`)
- Desktop: LightDM + Hyprland (base config)
- Network: NetworkManager with wpa_supplicant backend
    - WiFi should work out of the box if vendor drivers are available
    - Configure with `nmtui` or run `setup-nixos`

### Base setup flow

A terminal opens automatically on first boot. Run `setup-nixos` to step through:

1. **WiFi** — connects and enables autoconnect
2. **Expand rootfs** — grows the partition to fill the USB drive
3. **Verify config** — checks `~/nixos-shimboot`, optionally pulls updates
4. **Link `/etc/nixos`** — runs `setup-nixos-shimboot` to wire flake for `nixos-rebuild`
5. **Rebuild** — optional first rebuild from base config

After completing, the system is usable as a minimal NixOS install. For a full
desktop environment, layer on the companion config repo.

## Desktop Configuration

This step is optional. The base config provides a minimal Hyprland environment.
For Home Manager integration, theming, and personal applications, layer on
the companion config repo.

```bash
git clone https://github.com/PopCat19/nixos-shimboot-config.git
cd nixos-shimboot-config
git checkout main  # or your personal branch
```

The config repo imports shimboot as a flake input (`shimboot.nixosModules.chromeos`) and layers personal configuration on top. Users can fork the config repo and create their own branch for personalized setups.

## Troubleshooting

### "Git fetch failed" during setup-nixos

The git remote may be pointing to the build machine's path. Fix with:
```bash
cd ~/nixos-shimboot
git remote set-url origin https://github.com/PopCat19/nixos-shimboot-config.git # replace URL with your fork if utilized
git fetch origin
```

### "blockdev: Unknown command" during expand-rootfs

Run the script with DEBUG=1 to see what's failing:
```bash
sudo DEBUG=1 expand-rootfs
```

If it still fails, manually expand:
```bash
sudo growpart /dev/sdX N  # Replace X and N with your disk/partition
sudo resize2fs /dev/sdXN
```

### Build Issues

- Ensure you're using the correct board name (case-sensitive): dedede, grunt, hatch, nissa, octopus, snappy, zork
- For ChromeOS artifacts, ensure you have the correct board manifest
- Check cache health before building: `./tools/build/check-cachix.sh dedede`
- Use `--dry-run` to test the build process without destructive operations
- Enable cache pre-warming: `--prewarm-cache` to fetch derivations before building

### Cache Management

- Built-in Cachix integration for faster builds
- Check cache coverage: `./tools/build/check-cachix.sh [BOARD]`
- Cache automatically configured in Nix settings
- Push built derivations to cache for faster subsequent builds

### Boot Issues

- Verify your Chromebook board is in the supported list above
- Confirm the shim image matches your exact device model
- Check that recovery mode key combination is correct for your model
- Inspect build metadata: `cat /etc/shimboot-build.json` on the running system

### Space Issues

- Ensure `sudo expand_rootfs` succeeded in allocating rootfs to full USB space
- The base image is ~6-8GB (expandable); ensure your USB drive has enough space
- Use `--cleanup-rootfs` to remove old generations and free space
- Use `nix-shell` for temporary packages to save space

## Next Steps

- Fork the config repo and create a personal branch (use `main` as template)
- Import `shimboot.nixosModules.chromeos` as a hardware layer in your own flake
- Experiment with different desktop environments
- Contribute bug reports or improvements


