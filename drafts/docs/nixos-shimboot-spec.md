# NixOS Shimboot Technical Specification Draft
**Status:** Proof of Concept
**Last Updated:** 2025-10-24  

## Document Status

🚧 **This specification is subject to change**  
This is a living document that reflects the current implementation and planned features. Breaking changes may occur between versions.

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Project Goals](#project-goals)
3. [Architecture Overview](#architecture-overview)
4. [System Components](#system-components)
5. [Build Pipeline](#build-pipeline)
6. [Configuration System](#configuration-system)
7. [Boot Process](#boot-process)
8. [Deployment](#deployment)
9. [Security Considerations](#security-considerations)
10. [Known Limitations](#known-limitations)
11. [Future Roadmap](#future-roadmap)
12. [Appendices](#appendices)

---

## Executive Summary

### What is NixOS Shimboot?

NixOS Shimboot is a declarative, reproducible bootloader system that enables running full NixOS installations on enterprise-enrolled Chromebooks by leveraging ChromeOS RMA shim firmware vulnerabilities.

### Key Features

- ✅ **Declarative Configuration**: NixOS flake-based system configuration
- ✅ **No Firmware Modification**: Works without unenrollment or firmware changes
- ✅ **Multi-Board Support**: Infrastructure for multiple Chromebook models
- ✅ **Persistent Storage**: USB/SD card persistent Linux installation
- ✅ **Desktop Environment**: Full Hyprland Wayland compositor with HyprPanel
- ⚠️ **ChromeOS Coexistence**: Boot ChromeOS ROOT-A/B with donor drivers (experimental)

### Current Status

| Component | Status | Notes |
|-----------|--------|-------|
| Core Boot | ✅ Stable | Boots NixOS |
| Hyprland | ✅ Stable | Wayland window manager |
| Networking | ✅ Stable | WiFi works with vendor drivers |
| ChromeOS Boot | ⚠️ Experimental | Requires tmpfs staging fix |
| Audio | ❌ Limited | Board-dependent, USB audio recommended |
| Suspend | ❌ Not Available | ChromeOS kernel limitation |

---

## Project Goals

### Primary Objectives

1. **Enable NixOS on Chromebooks**: Provide a working NixOS system on ChromeOS hardware without firmware modification
2. **Declarative Configuration**: Leverage Nix flakes for reproducible system builds
3. **Educational Platform**: Demonstrate advanced Linux boot mechanisms and NixOS system design
4. **User Accessibility**: Provide prebuilt images and clear documentation for non-developers

### Non-Goals

1. **Production System**: Not intended for critical workloads (POC status)
2. **Full Hardware Support**: Audio and suspend are known limitations
3. **ChromeOS Feature Parity**: No attempt to replicate ChromeOS functionality
4. **Enterprise Support**: Community-driven, no SLA or warranty

---

## Architecture Overview

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     USB/SD Boot Media                       │
├─────────────────────────────────────────────────────────────┤
│  p1: STATE (1MB)       │ Dummy stateful partition           │
│  p2: KERN-A (32MB)     │ ChromeOS kernel + patched initramfs│
│  p3: BOOTLOADER (20MB) │ Shimboot bootloader                │
│  p4: VENDOR (dynamic)  │ ChromeOS drivers/firmware          │
│  p5: ROOTFS (dynamic)  │ NixOS root filesystem              │
└─────────────────────────────────────────────────────────────┘
         │
         ├─> Boot Flow:
         │   1. ChromeOS firmware loads KERN-A
         │   2. Patched initramfs runs shimboot bootloader
         │   3. Bootloader presents OS selection menu
         │   4. User selects NixOS or ChromeOS ROOT-A/B
         │   5. Bootloader performs pivot_root to selected OS
         │
         └─> NixOS Components:
             ├─> Base System (required)
             │   ├─ Patched systemd (mount_nofollow)
             │   ├─ NetworkManager + wpa_supplicant
             │   ├─ LightDM display manager
             │   └─ Hyprland compositor
             │
             └─> Optional Layers
                 ├─ Home Manager (user configuration)
                 ├─ Desktop applications
                 └─ Custom user modules
```

### Design Principles

1. **Separation of Concerns**
   - **Build-time**: Nix derivations (reproducible, sandboxed)
   - **Assembly-time**: Imperative scripts (loop devices, partitioning)
   - **Runtime**: Declarative NixOS configuration

2. **Layered Configuration**
   - **Base**: Minimal working system (bootable)
   - **Main**: Full desktop environment with Home Manager
   - **User**: Template for custom configurations

3. **Upstream Compatibility**
   - Bootloader and systemd patches from [ading2210/shimboot](https://github.com/ading2210/shimboot)
   - ChromeOS artifacts remain under Google's proprietary license
   - NixOS ports maintain GPL-3.0 licensing

---

## System Components

### 1. Bootloader (`bootloader/`)

**Purpose**: Transition from ChromeOS shim environment to Linux root filesystem

**Key Files**:
- `bin/init` - PID 1 initial process, installs BusyBox applets
- `bin/bootstrap.sh` - Main bootloader logic, OS selection menu
- `bin/crossystem` - Spoofs ChromeOS verified mode flags
- `bin/mount-encrypted` - Handles ChromeOS stateful partition

**Functions**:
```bash
# Core bootloader functions
find_all_partitions()      # Enumerate bootable partitions
print_selector()           # Display OS selection menu
get_selection()            # Handle user input
boot_target()              # Boot NixOS rootfs
boot_chromeos()            # Boot ChromeOS with donor drivers
```

**Boot Modes**:
- **Normal**: Boot into NixOS rootfs
- **ChromeOS**: Boot into ROOT-A/B with donor driver staging
- **Rescue**: Drop to shell for debugging

---

### 2. NixOS Configuration (`shimboot_config/`)

#### Base Configuration (`base_configuration/`)

**Purpose**: Minimal bootable NixOS system

**Modules**:
```
system_modules/
├── boot.nix              # Bootloader config (no grub/systemd-boot)
├── networking.nix        # NetworkManager + wpa_supplicant
├── filesystems.nix       # Single-partition layout
├── hardware.nix          # ChromeOS firmware enablement
├── systemd.nix           # Patched systemd + kill-frecon service
├── users.nix             # Default user account
├── audio.nix             # PipeWire (board-dependent)
├── display.nix           # LightDM + Hyprland
├── services.nix          # Essential system services
├── fish.nix              # Fish shell with custom functions
├── zram.nix              # Swap compression (NEW)
└── helpers/
    ├── filesystem-helpers.nix    # expand_rootfs
    ├── permissions-helpers.nix   # fix_bwrap
    ├── setup-helpers.nix         # setup_nixos wizard
    └── firewall-helpers.nix      # shimboot-enable-firewall (NEW)
```

**Size Target**: <8.0GB uncompressed, <6.0GB with squashfs

#### Main Configuration (`main_configuration/`)

**Purpose**: Full desktop environment with Home Manager

**Additional Modules**:
```
├── system_modules/
│   ├── fonts.nix         # System fonts
│   └── display.nix       # Hyprland integration
│
├── home_modules/         # Home Manager configuration
│   ├── hypr_config/      # Hyprland settings
│   │   ├── hyprland.nix
│   │   ├── hyprlock.nix
│   │   ├── fuzzel.nix
│   │   └── hypr_modules/
│   │       ├── animations.nix
│   │       ├── keybinds.nix
│   │       ├── window-rules.nix
│   │       └── autostart.nix
│   │
│   ├── packages/         # Application categories
│   │   ├── communication.nix  # Vesktop
│   │   ├── media.nix          # MPV, Audacious
│   │   ├── utilities.nix      # CLI tools
│   │   └── gaming.nix         # Lutris, OSU
│   │
│   ├── theme.nix         # Rose Pine theming
│   ├── kitty.nix         # Terminal config
│   ├── fish.nix          # Shell config with abbreviations
│   ├── starship.nix      # Prompt
│   ├── zen-browser.nix   # Browser with extensions
│   └── kde.nix           # KDE apps (Dolphin, Gwenview)
```

**Size Target**: <20.0GB uncompressed, <16.0GB with squashfs

---

### 3. Flake Structure (`flake.nix`)

**Inputs**:
```nix
inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  nixos-generators.url = "github:nix-community/nixos-generators";
  home-manager.url = "github:nix-community/home-manager";
  zen-browser.url = "github:0xc000022070/zen-browser-flake";
  rose-pine-hyprcursor.url = "github:ndom91/rose-pine-hyprcursor";
};
```

**Outputs** (per board):
```nix
packages.x86_64-linux = {
  # Build artifacts
  "chromeos-shim-${board}"          # ChromeOS RMA shim binary
  "chromeos-recovery-${board}"      # ChromeOS recovery image
  "extracted-kernel-${board}"       # Extracted KERN-A
  "initramfs-extraction-${board}"   # Extracted initramfs
  "initramfs-patching-${board}"     # Patched with bootloader
  
  # System images
  "raw-rootfs"                      # Full image (main config)
  "raw-rootfs-minimal"              # Base image (minimal config)
};

nixosConfigurations = {
  "${hostname}"                     # Full system
  "${hostname}-minimal"             # Minimal system
};
```

---

### 4. Build Scripts

#### `assemble-final.sh`

**Purpose**: Orchestrate complete image creation

**Steps**:
```
Step 0: Build Nix outputs
  ├─> raw-rootfs image
  ├─> extracted-kernel
  └─> patched-initramfs

Step 0.5: Harvest ChromeOS drivers
  ├─> Mount shim and recovery images
  ├─> Extract /lib/modules, /lib/firmware
  ├─> Decompress .ko.gz modules
  └─> Run depmod for each kernel

Step 0.6: Augment with upstream linux-firmware (optional)

Step 1-2: Calculate partition sizes

Step 3-4: Create and partition disk image
  ├─> p1: STATE (1MB)
  ├─> p2: KERN-A (32MB)
  ├─> p3: BOOTLOADER (20MB)
  ├─> p4: VENDOR (calculated)
  └─> p5: ROOTFS (calculated)

Step 5-6: Setup loop device and format

Step 7: Populate bootloader partition

Step 8: Populate rootfs partition
  └─> Step 8.1: Driver injection (vendor/inject/both/none)
  └─> Step 8.2: Clone nixos-config repo

Step 9 (optional): Inspect image
```

**Options**:
```bash
--board BOARD          # Chromebook board name
--rootfs full|minimal  # Configuration variant
--drivers vendor|inject|both|none  # Driver handling
--luks                 # Enable LUKS2 encryption (NEW)
--compress-store       # squashfs /nix/store (NEW)
--inspect              # Inspect after build
```

#### `write-shimboot-image.sh`

**Purpose**: Safe USB/SD card writer with multiple validation gates

**Safety Features**:
- System disk detection and blocking
- Ignore lists for known system devices
- Large device confirmation (>256GB)
- Auto-unmount mounted filesystems
- Interactive confirmation prompts

---

## Build Pipeline

### Reproducibility Matrix

| Component | Reproducible? | Why / Why Not |
|-----------|---------------|---------------|
| Raw rootfs | ✅ Yes | Nix derivation, deterministic |
| Kernel extraction | ✅ Yes | Fixed shim input, deterministic tools |
| Initramfs patching | ✅ Yes | Fixed inputs, no external state |
| Driver harvesting | ⚠️ Mostly | Depends on shim/recovery versions |
| Disk image creation | ❌ No | Loop devices, timestamp in image |
| Final USB write | ❌ No | Hardware-specific operation |

### Build Isolation

**Pure Nix Operations** (sandboxed):
- Building NixOS system
- Extracting ChromeOS artifacts (read-only)
- Patching initramfs files

**Impure Operations** (require root):
- Creating loop devices
- Mounting filesystems
- Writing to block devices

### Dependency Graph

```
┌─────────────────┐
│  flake.nix      │
└────────┬────────┘
         │
    ┌────┴────┐
    │         │
    v         v
┌────────┐ ┌──────────────┐
│ nixpkgs│ │ nixos-       │
│        │ │ generators   │
└────┬───┘ └──────┬───────┘
     │            │
     └─────┬──────┘
           │
           v
    ┌──────────────┐
    │ raw-rootfs   │
    │ derivation   │
    └──────┬───────┘
           │
           v
    ┌──────────────────┐
    │ assemble-final.sh│ (imperative)
    └──────┬───────────┘
           │
    ┌──────┴──────────────┐
    │                     │
    v                     v
┌─────────────┐    ┌──────────────┐
│ harvest-    │    │ chromeos-    │
│ drivers.sh  │    │ shim/recovery│
└─────┬───────┘    └──────┬───────┘
      │                   │
      └─────────┬─────────┘
                │
                v
         ┌──────────────┐
         │ shimboot.img │
         └──────────────┘
```

---

## Configuration System

### User Configuration Pattern

**Central Definition** (`user-config.nix`):
```nix
{
  hostname ? null,
  system ? "x86_64-linux",
  username ? "nixos-user",
}: rec {
  host.hostname = hostname ?? username;
  
  user = {
    inherit username;
    shell = "fish";
    extraGroups = [ "wheel" "networkmanager" "video" ];
  };
  
  defaultApps = {
    browser = { desktop = "zen-twilight.desktop"; ... };
    terminal = { desktop = "kitty.desktop"; ... };
    # ...
  };
  
  directories = { /* XDG dirs */ };
}
```

**Consumption Pattern**:
```nix
# In any module:
{ userConfig, ... }: {
  users.users.${userConfig.user.username} = { /* ... */ };
  
  xdg.mimeApps.defaultApplications = {
    "text/html" = [ userConfig.defaultApps.browser.desktop ];
  };
}
```

### Configuration Layers

```
┌─────────────────────────────────────────┐
│  User Custom Config (template-based)    │ ← User's personal config (optional)
├─────────────────────────────────────────┤
│  Main Configuration (Home Manager)      │ ← Full desktop
├─────────────────────────────────────────┤
│  Base Configuration (required)          │ ← Minimal bootable
├─────────────────────────────────────────┤
│  NixOS Modules (nixpkgs)                │ ← System defaults
└─────────────────────────────────────────┘
```

**Override Precedence**:
1. User custom modules (highest)
2. Main configuration
3. Base configuration
4. NixOS defaults (lowest)

### Overlay System

**Current Overlays** (`overlays/overlays.nix`):
```nix
[
  # Patched systemd from Cachix
  (final: prev: {
    systemd = /* ... shimboot patched version ... */;
  })
  
  # Rose Pine themes
  (final: prev: {
    rose-pine-gtk-theme-full = /* ... */;
  })
]
```

**Usage**:
```nix
# Applied in flake.nix system configurations
({ config, ... }: {
  nixpkgs.overlays = import ../overlays/overlays.nix config.nixpkgs.system;
})
```

---

## Boot Process

### Detailed Boot Sequence (main_configuration; full-rootfs)

```
┌─────────────────────────────────────────────────────────────┐
│ 1. ChromeOS Firmware (Read-only, signed)                    │
│    - Verifies KERN-A signature (passes: shim is signed)     │
│    - Loads kernel from p2 into memory                       │
│    - Decompresses kernel                                    │
│    - Extracts and mounts initramfs                          │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       v
┌─────────────────────────────────────────────────────────────┐
│ 2. Patched Initramfs (PID 1: /init)                         │
│    - Installs BusyBox applets                               │
│    - Detects TTY (tty1/hvc0)                                │
│    - Execs /bin/bootstrap.sh                                │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       v
┌─────────────────────────────────────────────────────────────┐
│ 3. Shimboot Bootloader (/bin/bootstrap.sh)                  │
│    a. Enable debug console on TTY2                          │
│    b. Scan for bootable partitions                          │
│       - ChromeOS ROOT-A/B (cgpt find -l)                    │
│       - Shimboot partitions (fdisk, shimboot_rootfs:NAME)   │
│       - Vendor partition (shimboot_vendor label)            │
│    c. Display OS selection menu                             │
│    d. Wait for user input                                   │
└──────────────────────┬──────────────────────────────────────┘
                       │
        ┌──────────────┴──────────────┐
        │                             │
        v                             v
┌───────────────────┐      ┌──────────────────────┐
│ 4a. boot_target() │      │ 4b. boot_chromeos()  │
│  (NixOS)          │      │  (ChromeOS ROOT)     │
└───────┬───────────┘      └──────────┬───────────┘
        │                             │
        v                             v
┌─────────────────────────────────────────────────┐
│ Mount rootfs                                    │
│   - Check for LUKS (cryptsetup luksDump)        │
│   - If encrypted: prompt for password, open     │
│   - Mount to /newroot                           │
└────────────────────┬────────────────────────────┘
                     │
                     v
┌─────────────────────────────────────────────────┐
│ Vendor Driver Integration (if vendor partition) │
│   - Find vendor partition (by label/cgpt)       │
│   - Mount vendor read-only                      │
│   - Bind /lib/modules → /newroot/lib/modules    │
│   - Bind /lib/firmware → /newroot/lib/firmware  │
└────────────────────┬────────────────────────────┘
                     │
                     v
┌─────────────────────────────────────────────────┐
│ Kill frecon (if present)                        │
│   - Unmount /dev/console (frecon owns it)       │
│   - pkill frecon-lite                           │
│   - Bind TTY1 to /dev/console for systemd       │
└────────────────────┬────────────────────────────┘
                     │
                     v
┌─────────────────────────────────────────────────┐
│ pivot_root                                      │
│   - Move mounts (/sys, /proc, /dev) to newroot  │
│   - pivot_root /newroot /newroot/bootloader     │
│   - exec /sbin/init < TTY1 >> TTY1 2>&1         │
└────────────────────┬────────────────────────────┘
                     │
                     v
┌─────────────────────────────────────────────────┐
│ 5. systemd (PID 1 in new root)                  │
│    - systemd-udevd.service                      │
│    - NetworkManager.service                     │
│    - kill-frecon.service (ensure frecon dead)   │
│    - display-manager.service (LightDM)          │
│    - home-manager-*.service (if enabled)        │
└────────────────────┬────────────────────────────┘
                     │
                     v
┌─────────────────────────────────────────────────┐
│ 6. LightDM Greeter                              │
│    - Display login screen                       │
│    - User authentication                        │
│    - Launch desktop session                     │
└────────────────────┬────────────────────────────┘
                     │
                     v
┌─────────────────────────────────────────────────┐
│ 7. Hyprland Session                             │
│    - Start Hyprland compositor                  │
│    - Launch HyprPanel                           │
│    - Start hyprpaper (wallpaper)                │
│    - User applications                          │
└─────────────────────────────────────────────────┘
```

### ChromeOS Boot Specifics

**For ChromeOS ROOT-A/B boot**:
```bash
boot_chromeos() {
  # 1. Mount ChromeOS root (read-only)
  mount -o ro $target /newroot
  
  # 2. Create tmpfs for writable overlay
  mount -t tmpfs none /newroot/tmp
  
  # 3. Mount donor (vendor) partition
  mount -o ro $donor /newroot/tmp/donor_mnt
  
  # 4. CRITICAL: Copy to tmpfs (not bind from donor!)
  copy_progress /newroot/tmp/donor_mnt/lib/modules /newroot/tmp/donor/lib/modules
  copy_progress /newroot/tmp/donor_mnt/lib/firmware /newroot/tmp/donor/lib/firmware
  
  # 5. Bind from tmpfs into ChromeOS root
  mount -o bind /newroot/tmp/donor/lib/modules /newroot/lib/modules
  mount -o bind /newroot/tmp/donor/lib/firmware /newroot/lib/firmware
  
  # 6. Unmount donor (no longer needed)
  umount /newroot/tmp/donor_mnt
  
  # 7. Apply ChromeOS patches (crossystem spoofing, etc.)
  # ...
  
  # 8. pivot_root and exec ChromeOS init
}
```

**Why tmpfs staging is required**:
- ChromeOS init expects modules in `/tmp` during early boot
- Direct bind from external partition fails if unmounted during init
- tmpfs persists through pivot_root and ChromeOS early startup

---

## Deployment

### Build Environment Requirements

**Host System**:
- Linux system (NixOS, Debian, Ubuntu, Arch, etc.)
- Nix with flakes enabled
- >=40GB free disk space
- Internet connection for downloads

**Required Packages**:
- `nix` (2.13+)
- `sudo` (for loop device operations)
- `git` (for cloning repo)

### Build Commands
> Replace `<board-name>` with compatible target board: dedede, grunt, hatch, nissa, octopus, snappy, zork

**Basic build**:
```bash
git clone https://github.com/PopCat19/nixos-shimboot.git
cd nixos-shimboot
sudo ./assemble-final.sh --board <board-name> --rootfs full
```

**Advanced builds**:
```bash
# Minimal image
sudo ./assemble-final.sh --board <board-name> --rootfs minimal

# Encrypted image
sudo ./assemble-final.sh --board <board-name> --rootfs full --luks

# Compressed image (squashfs /nix/store)
sudo ./assemble-final.sh --board <board-name> --rootfs full --compress-store

# All options combined
sudo ./assemble-final.sh \
  --board <board-name> \
  --rootfs full \
  --luks \
  --compress-store \
  --drivers vendor
```

### Flashing Process
> Replace `/dev/sdX` with target USB/SD device

**Interactive (recommended)**:
```bash
sudo ./write-shimboot-image.sh --list  # Show available devices
sudo ./write-shimboot-image.sh -i work/shimboot.img --output /dev/sdX
```

**Manual (advanced)**:
```bash
# Using dd directly
sudo dd if=work/shimboot.img of=/dev/sdX bs=4M status=progress oflag=sync
```

### First Boot

1. **Enter Recovery Mode**:
   - Typical combo: `Esc + Refresh + Power`
   - Or device-specific key combination

1.1. **Enable Developer Mode (one-time config; semi-persistent)**:
   - Combo: `Ctrl + D`
   - Confirm prompt (enter developer mode)
   - Repeat step 1 key combination, then move to step 2

2. **Boot from USB**:
   - Insert shimboot USB
   - Chromebook detects as "recovery media"
   - If unsupported, enable Developer Mode at step 1.1
   - Boots into shimboot bootloader

3. **Select OS**:
   ```
   ┌──────────────────────┐
   │ Shimboot OS Selector │
   └──────────────────────┘
   1) ChromeOS_ROOT-A on /dev/mmcblk1p3
   2) ChromeOS_ROOT-B on /dev/mmcblk1p5
   3) nixos on /dev/sda5
   q) reboot
   s) enter a shell
   
   Your selection: 3
   ```

4. **Login**:
   - LightDM greeter appears
   - Default credentials: `nixos-user` / `nixos-shimboot` (prebuilt images)
   - Or custom credentials (self-built)

5. **Post-Install Setup**:
   ```bash
   # Expand rootfs to full USB capacity
   sudo expand_rootfs
   
   # Run interactive setup wizard
   setup_nixos
   ```

---

## Security Considerations

### Threat Model

**In Scope**:
- USB/SD card theft (mitigated by LUKS2 encryption)
- Unauthorized access to system (standard Linux PAM auth)
- Malicious packages (Nix store integrity)

**Out of Scope**:
- ChromeOS firmware vulnerabilities (inherited from upstream)
- Physical access attacks (bootloader is unprotected)
- Enterprise enrollment detection (intentional for shimboot use case)

### Security Features

| Feature | Status | Implementation |
|---------|--------|----------------|
| Disk Encryption | ✅ LUKS2 | cryptsetup luksFormat (AES-XTS-256) |
| Secure Boot | ❌ N/A | ChromeOS verifies KERN-A only |
| Firewall | ⚠️ Disabled by default | Unsupported |
| User Isolation | ✅ Standard Linux | PAM + sudo |
| Package Verification | ✅ Nix Store | SHA256 hashes, binary cache signatures |

### Best Practices

1. **Change Default Passwords**:
   ```bash
   passwd nixos-shimboot  # Change default user password
   sudo passwd  # Set root password
   ```

2. **Use LUKS Encryption**:
   ```bash
   # At build time
   ./assemble-final.sh --board dedede --rootfs full --luks
   ```

3. **Keep System Updated**:
   ```bash
   cd ~/nixos-config
   nix flake update
   nixos-rebuild-basic
   ```

---

## Known Limitations

### Hardware Limitations

| Feature | Status | Workaround |
|---------|--------|------------|
| Audio | ❌ Most boards | USB sound card |
| Suspend | ❌ All boards | None (kernel limitation) |
| Bluetooth | ⚠️ Board-dependent | Check compatibility table |
| Touchscreen | ⚠️ Board-dependent | Usually works (DE/WM config dependent) |
| 3D Acceleration | ⚠️ Board-dependent | Mesa/Intel drivers |

### Software Limitations

1. **ChromeOS Kernel**:
   - No suspend support (CONFIG_PM_SUSPEND disabled)
   - Limited kernel namespaces (<5.6) - requires `--option sandbox false`
   - Missing kernel modules for some hardware

2. **Disk Space**:
   - Base image: ~6-8GB (can expand with `expand_rootfs`)
   - `nix-shell` requires space (use squashfs for compression)

3. **Performance**:
   - USB 2.0 speeds (slow on old drives)
   - <=4GB RAM devices struggle with large builds

### Incompatible Boards

**Enrolled Chromebooks manufactured after early 2023**:
- Contain read-only firmware patch blocking sh1mmer/shimboot
- No known workaround for enrolled devices

**Boards with patched shims**:
```
reef, sand, pyro
```
These boards have shims with the vulnerability patched.

---

## Future Roadmap (subject to change)

- [ ] Zram configuration
- [ ] Firewall helper scripts
- [ ] LUKS2 encryption support
- [ ] squashfs /nix/store compression
- [ ] ChromeOS ROOT_A/B tmpfs staging fix
- [ ] Multi-board testing (octopus, zork, nissa)
- [ ] NixOS generation selector in bootloader
- [ ] Systemd Cachix integration (reduce on-device rebuilds)
- [ ] Configuration template system
- [ ] Improved post-install wizard
- [ ] Full multi-board support (all compatible boards tested)
- [ ] Proper documentation website
- [ ] Binary cache for all shimboot packages
- [ ] Alternative WM/DE (Niri, KDE Plasma, Cosmic)

### Research / Experimental

- [ ] kexec support (boot different kernels without reboot)

---

## Appendices

### Appendix A: Supported Boards (data from ading2210/shimboot/README.md)

| Board Name | Model Examples | CPU | Status | Notes |
|------------|---------------|-----|--------|-------|
| dedede | HP 11 G9 EE | Intel Celeron N4500 | ✅ Tested | Reference board |
| octopus | Lenovo 100e | Intel Celeron N4000 | ⚠️ Untested | Should work |
| zork | HP 14 G7 | AMD Ryzen 3 3250C | ⚠️ Untested | Should work |
| nissa | HP Chromebook 14 G7 | Intel N100 | ⚠️ Untested | Newer board |
| hatch | Acer Chromebook 311 | Intel Core i3 | ⚠️ Untested | 5GHz WiFi issues |
| corsola | Lenovo IdeaPad Slim 3 | MediaTek Kompanio 520 | ❌ ARM64 (currently not supported) | May require qemu-user-static |
| grunt | Acer Chromebook 315 | AMD A4-9120C | ⚠️ Untested | WiFi driver issues |
| jacuzzi | ASUS Chromebook Flip CM3 | MediaTek MT8183 | ❌ ARM64 (currently not supported) | No audio |
| hana | Acer Chromebook R11 | MediaTek MT8173C | ❌ ARM64 (currently not supported) | Very old |
| snappy | Dell Chromebook 11 | Intel Celeron N2840 | ⚠️ Untested | Old Braswell |

### Appendix B: Kernel Namespace Workaround

**For ChromeOS kernels <5.6** (missing user namespaces):

```bash
# When running nixos-rebuild
sudo nixos-rebuild switch \
  --flake . \
  --option sandbox false
```

**Why this is needed**:
- Nix build sandbox requires `CLONE_NEWUSER` namespace
- ChromeOS kernels <5.6 lack this feature
- Disabling sandbox allows builds to proceed

**Fish function** (already in base config):
```fish
function nixos-rebuild-basic
  # Auto-detects kernel version and adds --option sandbox false if needed
end
```

### Appendix C: Glossary

- **Shimboot**: The overall project name; boot system using ChromeOS shim
- **Shim**: ChromeOS RMA (Return Merchandise Authorization) diagnostic image
- **KERN-A/B**: ChromeOS kernel partitions (A/B for A/B updates)
- **ROOT-A/B**: ChromeOS root filesystem partitions
- **Vendor Partition**: Partition holding ChromeOS drivers/firmware for donor mode
- **pivot_root**: Linux syscall to change the root filesystem
- **initramfs**: Initial RAM filesystem, runs before real root is mounted
- **cgpt**: ChromeOS GPT partition tool
- **frecon-lite**: ChromeOS framebuffer console (blocks X11/Wayland)

### Appendix D: Troubleshooting

**Build fails with "loop device not found"**:
```bash
# Check available loop devices
ls /dev/loop*

# Create more if needed
sudo mknod /dev/loop8 b 7 8
```

**"Firewall.service failed" at boot**:
```bash
# Disable firewall (temporary; already declaratively default in recent versions)
sudo systemctl disable firewall.service
```

**"No space left on device" during nix-shell**:
```bash
# Expand rootfs first
sudo expand_rootfs

# Or use squashfs image to save space
```

**LightDM shows black screen**:
```bash
# Check if frecon is killed (if you have terminal access via SSH)
systemctl status kill-frecon.service

# Check LightDM logs (or extract journal to another system)
journalctl -u lightdm.service

# Try restarting (if you have terminal access via SSH)
sudo systemctl restart lightdm.service
```

---

## Document History

| Date | Changes |
|------|---------|
| 2025-10-24 | Initial spec draft |

---

## References

1. [Original Shimboot](https://github.com/ading2210/shimboot) - Upstream project
2. [sh1mmer](https://sh1mmer.me/) - RMA shim vulnerability documentation
3. [ChromeOS Systemd Patches](https://github.com/ading2210/chromeos-systemd) - mount_nofollow patch
4. [NixOS Manual](https://nixos.org/manual/nixos/stable/) - NixOS configuration
5. [Home Manager](https://nix-community.github.io/home-manager/) - User environment management