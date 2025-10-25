# NixOS Shimboot Technical Specification

**Status:** Proof of Concept  
**Target:** ChromeOS devices with RMA shim vulnerability  
**License:** GPL-3.0 (code) / Unfree (ChromeOS artifacts)

---

## 1. Project Identity

### What This Is
- NixOS distribution bootable via ChromeOS RMA shim exploit
- Declarative system built with Nix flakes
- No firmware modification required
- Boots from USB/SD persistent storage

### What This Is Not
- Production-ready system
- Enterprise-supported solution
- Audio/suspend-capable environment
- Replacement for proper Linux installation

### Tested Hardware
```
HP Chromebook 11 G9 EE (dedede board)
├─ Status: Working
├─ WiFi: Functional (vendor drivers)
├─ Display: Hyprland compositing works
├─ Audio: Limited/non-functional
└─ Suspend: Not available (kernel limitation)
```

### Supported Boards (Infrastructure Only)
```
dedede, octopus, zork, nissa, hatch, grunt, snappy
└─ Note: Only dedede confirmed working as of writing
```

---

## 2. System Architecture

### Layer Model
```
User Applications
    ↓
Home Manager Configuration
    ↓
NixOS System (patched systemd)
    ↓
Shimboot Bootloader (BusyBox)
    ↓
ChromeOS Kernel + Patched Initramfs
    ↓
ChromeOS Firmware (verified boot)
```

### Disk Layout (GPT)
```
p1: STATE (1MB)       - ChromeOS stateful (dummy)
p2: KERN-A (32MB)     - ChromeOS kernel + patched initramfs
p3: BOOTLOADER (20MB) - Shimboot bootloader scripts
p4: VENDOR (dynamic)  - ChromeOS drivers/firmware donor
p5: ROOTFS (dynamic)  - NixOS root filesystem (expandable)
```

### Critical Patches
```
systemd
└─ mount_nofollow.patch
   ├─ Disables symlink following in mount operations
   ├─ Required: ChromeOS kernel filesystem assumptions
   └─ Source: ading2210/chromeos-systemd

ChromeOS initramfs
└─ bootloader overlay
   ├─ Replaces /init with shimboot bootstrap
   └─ Source: ading2210/shimboot
```

---

## 3. Component Reference

### Build Artifacts (per board)
```
chromeos-shim-${board}
├─ Type: Unfree binary
├─ Source: ChromeOS CDN (manifest-based download)
└─ Contains: Firmware, kernel, initramfs

chromeos-recovery-${board} (optional)
├─ Type: Unfree binary
├─ Source: Google recovery API
└─ Purpose: Firmware/driver harvesting

extracted-kernel-${board}
├─ Input: chromeos-shim
├─ Output: kernel.bin (vbutil_kernel blob)
└─ Method: KERN-A partition extraction + CHROMEOS magic search

initramfs-extraction-${board}
├─ Input: extracted-kernel
├─ Output: initramfs.tar (unpacked cpio)
└─ Method: futility vbutil_kernel + multi-layer decompression

initramfs-patching-${board}
├─ Input: initramfs-extraction, bootloader/
├─ Output: patched-initramfs/ (directory)
└─ Method: Overlay bootloader scripts over initramfs

raw-rootfs (board-independent)
├─ Input: main_configuration/, home-manager
├─ Output: nixos.img (ext4 filesystem)
└─ Generator: nixos-generators (raw format)

raw-rootfs-minimal (board-independent)
├─ Input: base_configuration/ only
├─ Output: nixos.img (ext4 filesystem)
└─ Generator: nixos-generators (raw format)
```

### Configuration Variants
```
base_configuration/
├─ Purpose: Minimal bootable system
├─ Size Target: <8GB
├─ Display: LightDM + Hyprland (standalone)
├─ Users: root + nixos-user (initial password: nixos-shimboot)
└─ Features: NetworkManager, Fish shell, system helpers

main_configuration/
├─ Purpose: Full desktop environment
├─ Size Target: <20GB
├─ Display: LightDM + Hyprland + HyprPanel
├─ Extends: base_configuration
├─ Adds: Home Manager, user applications, theming
└─ Features: Rose Pine theme, Zen browser, KDE apps
```

---

## 4. Build Pipeline

### Reproducibility Matrix
```
Component              | Reproducible | Notes
-----------------------|--------------|------------------------
Raw rootfs             | Yes          | Nix derivation
Kernel extraction      | Yes          | Fixed shim input
Initramfs patching     | Yes          | Fixed inputs
Driver harvesting      | Mostly       | Depends on shim/recovery versions
Disk image creation    | No           | Loop devices, timestamps
USB write              | No           | Hardware-specific
```

### Build Graph
```
flake.nix
├─ nixos-generators (imports)
│  └─ base_configuration/ OR main_configuration/
│     └─ raw-rootfs.img
│
├─ chromeos-shim-${board}
│  ├─ extracted-kernel-${board}
│  │  └─ initramfs-extraction-${board}
│  │     └─ initramfs-patching-${board}
│  │
│  └─ (optional) chromeos-recovery-${board}
│     └─ harvest-drivers.sh
│        └─ harvested/
│           ├─ lib/modules/
│           ├─ lib/firmware/
│           └─ modprobe.d/
│
└─ assemble-final.sh (imperative)
   ├─ Inputs: raw-rootfs.img, patched-initramfs/, harvested/
   ├─ Creates: shimboot.img (partitioned disk image)
   └─ Integrates: vendor drivers (vendor/inject/both/none)
```

### Pure vs Impure Operations
```
Pure (Nix sandbox):
├─ Building NixOS system
├─ Extracting ChromeOS artifacts
└─ Patching initramfs files

Impure (requires root):
├─ Creating loop devices
├─ Mounting filesystems
├─ Writing to block devices
└─ Running depmod (during harvest)
```

---

## 5. Configuration System

### User Configuration Entry Point
```
shimboot_config/user-config.nix
├─ host.hostname        - System hostname
├─ host.system          - Architecture (x86_64-linux)
├─ user.username        - Primary user account name
├─ user.shellPackage    - Default shell (fish)
├─ user.extraGroups     - System groups
├─ defaultApps.*        - MIME handlers and launchers
├─ timezone             - System timezone
├─ locale               - System locale
└─ directories.*        - XDG directory paths
```

### Configuration Layers
```
┌─────────────────────────────────────┐
│ User Custom Config (template-based) │ ← Highest priority
├─────────────────────────────────────┤
│ Main Configuration (Home Manager)   │
├─────────────────────────────────────┤
│ Base Configuration (required)       │
├─────────────────────────────────────┤
│ NixOS Modules (nixpkgs)             │ ← Lowest priority
└─────────────────────────────────────┘
```

### Module Structure
```
base_configuration/
├─ configuration.nix                - Main entry point
└─ system_modules/
   ├─ boot.nix                      - Disables standard bootloaders
   ├─ networking.nix                - NetworkManager + wpa_supplicant
   ├─ filesystems.nix               - Single ext4 partition
   ├─ hardware.nix                  - Firmware enablement
   ├─ systemd.nix                   - Patched systemd + kill-frecon service
   ├─ users.nix                     - Default user accounts
   ├─ display.nix                   - LightDM + Hyprland
   ├─ packages.nix                  - Minimal system packages
   ├─ fish.nix                      - Fish shell + Starship
   ├─ zram.nix                      - Swap compression
   └─ helpers/
      ├─ filesystem-helpers.nix     - expand_rootfs
      ├─ permissions-helpers.nix    - permission utilities
      ├─ setup-helpers.nix          - setup_nixos wizard

main_configuration/
├─ configuration.nix                - Imports base + adds user modules
├─ system_modules/
│  ├─ display.nix                   - Hyprland integration
│  ├─ fonts.nix                     - System fonts
│  └─ packages.nix                  - User applications
│
└─ home_modules/
   ├─ home.nix                      - Home Manager entry point
   ├─ hypr_config/                  - Hyprland settings
   │  ├─ hyprland.nix
   │  ├─ hyprpanel-home.nix
   │  └─ hypr_modules/
   │     ├─ colors.nix
   │     ├─ animations.nix
   │     ├─ keybinds.nix
   │     └─ window-rules.nix
   │
   ├─ packages/                     - Application categories
   │  ├─ communication.nix          - Vesktop
   │  ├─ media.nix                  - MPV, Audacious
   │  ├─ utilities.nix              - CLI tools
   │  └─ gaming.nix                 - Lutris, OSU
   │
   ├─ theme.nix                     - Rose Pine theming
   ├─ kitty.nix                     - Terminal config
   ├─ fish.nix                      - Shell abbreviations
   ├─ zen-browser.nix               - Browser with extensions
   └─ kde.nix                       - KDE apps (Dolphin, Gwenview)
```

---

## 6. Boot Mechanism

### Execution Tree
```
ChromeOS Firmware (PID 0)
└─ Loads KERN-A (p2) into memory
   └─ Decompresses kernel
      └─ Mounts initramfs
         └─ /init (PID 1: BusyBox sh)
            └─ Installs BusyBox applets
               └─ Detects TTY (tty1/hvc0)
                  └─ Execs bootstrap.sh
                     └─ Scans for partitions
                        ├─ ChromeOS ROOT-A/B (cgpt find -l)
                        ├─ shimboot_rootfs:* (fdisk, partition name)
                        └─ shimboot_vendor (FS label or PARTLABEL)
                           └─ Displays selection menu
                              └─ User selects NixOS
                                 └─ boot_target()
                                    ├─ Check for LUKS
                                    │  └─ Prompt for password
                                    │     └─ cryptsetup open
                                    ├─ Mount rootfs (ext4)
                                    ├─ bind_vendor_into()
                                    │  └─ Mount vendor (read-only)
                                    │     ├─ Bind lib/modules
                                    │     └─ Bind lib/firmware
                                    ├─ Kill frecon-lite
                                    ├─ Move /sys, /proc, /dev to newroot
                                    └─ pivot_root /newroot /newroot/bootloader
                                       └─ exec /sbin/init < TTY1 >> TTY1 2>&1
                                          └─ systemd (PID 1 in new root)
                                             ├─ systemd-udevd.service
                                             ├─ NetworkManager.service
                                             ├─ kill-frecon.service
                                             └─ display-manager.service (LightDM)
                                                └─ LightDM Greeter
                                                   └─ User login
                                                      └─ Hyprland Session
                                                         ├─ HyprPanel
                                                         ├─ hyprpaper
                                                         └─ User applications
```

### Vendor Driver Integration
```
vendor partition (p4)
├─ lib/modules/          - ChromeOS kernel modules
└─ lib/firmware/         - ChromeOS firmware blobs

bind_vendor_into()
├─ Mount vendor read-only at /newroot/.vendor
├─ Bind /newroot/.vendor/lib/modules → /newroot/lib/modules
└─ Bind /newroot/.vendor/lib/firmware → /newroot/lib/firmware

Why bind instead of copy?
├─ Memory efficiency (no tmpfs staging)
├─ Faster boot time
└─ Persistent across pivot_root
```

### ChromeOS Boot Path (Experimental)
```
boot_chromeos()
├─ Mount ChromeOS root (read-only)
├─ Create tmpfs overlay
├─ Mount donor partition
├─ Copy modules/firmware to tmpfs (required for ChromeOS init)
├─ Bind from tmpfs into ChromeOS root
├─ Unmount donor (no longer needed after copy)
├─ Apply ChromeOS patches (crossystem spoofing)
└─ pivot_root and exec ChromeOS init

Note: Direct bind from donor fails; ChromeOS init expects /tmp
```

---

## 7. Known Constraints

### Hardware Support
```
Feature       | Status      | Notes
--------------|-------------|----------------------------------
WiFi          | Working     | Requires vendor drivers
Bluetooth     | Variable    | Board-dependent
Audio         | Limited     | Most boards non-functional
Suspend       | Unavailable | CONFIG_PM_SUSPEND disabled
Touchscreen   | Variable    | Usually works if DE/WM supports
3D Accel      | Variable    | Mesa/Intel drivers
```

### Software Limitations
```
ChromeOS Kernel
├─ No suspend support
├─ Limited namespaces (<5.6 requires --option sandbox false)
└─ Missing some kernel modules

Disk Space
├─ Base image: ~6-8GB (expandable with expand_rootfs)
├─ Full image: ~16-20GB (expandable with expand_rootfs)
└─ nix-shell requires space

Performance
├─ USB 2.0 bottleneck on older drives
├─ 4GB RAM devices struggle with large builds
└─ nix flake check may OOM (use --option sandbox false)
```

### Incompatible Configurations
```
Enrolled Chromebooks manufactured after early 2023
└─ Firmware patch blocks sh1mmer/shimboot
   └─ No workaround for enrolled devices

Boards with patched shims
└─ reef, sand, pyro
   └─ Shim vulnerability patched
```

---

## 8. Extension Points

### Adding New Boards
```
Required files:
├─ manifests/${board}-manifest.nix
│  ├─ Generated by: tools/fetch-manifest.sh
│  └─ Contains: Chunk list + hash
│
├─ flake_modules/chromeos-sources.nix
│  └─ Add recovery URL + hash for board
│
└─ flake.nix
   └─ Add board to supportedBoards list

Test build:
└─ nix build .#chromeos-shim-${board}
```

### Adding System Packages
```
base_configuration/system_modules/packages.nix
└─ environment.systemPackages = [ pkgs.your-package ];

main_configuration/home_modules/packages/
└─ Create category file (e.g., development.nix)
   └─ home.packages = [ pkgs.your-package ];
```

### Adding Helper Scripts
```
base_configuration/system_modules/helpers/your-helpers.nix
└─ environment.systemPackages = [
     (writeShellScriptBin "your-command" ''
       # script content
     '')
   ];

Import in:
└─ base_configuration/system_modules/helpers/helpers.nix
```

### Creating Custom Configurations
```
1. Fork main_configuration/ structure
2. Modify user-config.nix for your preferences
3. Build with: nix build .#raw-rootfs
4. Flash to USB with: tools/write-shimboot-image.sh
```

### Multi-Rootfs Setup (Manual)
```
Current: Single rootfs (p5)
Proposed: Multiple rootfs partitions

1. Modify bootstrap.sh to detect shimboot_rootfs:* pattern
2. Add menu entries for each detected partition
3. Use same boot_target() logic for each

Example partition layout:
├─ p5: shimboot_rootfs:nixos-stable
├─ p6: shimboot_rootfs:nixos-testing
└─ p7: shimboot_rootfs:nixos-minimal
```

---

## 9. Maintenance Guide

### When to Update This Spec

**Component Changes:**
```
flake.nix modified
└─ Update: Section 3 (Component Reference)

New configuration module added
└─ Update: Section 5 (Configuration System)

Build process changed
└─ Update: Section 4 (Build Pipeline)

Boot mechanism altered
└─ Update: Section 6 (Boot Mechanism)

Hardware compatibility discovered
└─ Update: Section 1 (Tested Hardware)
          Section 7 (Known Constraints)

New extension point created
└─ Update: Section 8 (Extension Points)
```

### Updating Build Artifacts
```
tools/fetch-manifest.sh ${board}
├─ Updates: manifests/${board}-manifest.nix
└─ Triggers: Rebuild of chromeos-shim-${board}

tools/fetch-recovery.sh
├─ Updates: flake_modules/chromeos-sources.nix (recovery URLs)
└─ Triggers: Rebuild of chromeos-recovery-${board}
```

### Spec File Organization
```
Each section is independently updateable
└─ Changes to Section N should not require rewriting Section M

Avoid:
├─ Cross-references between sections (prefer duplication)
├─ Time-sensitive data (use "current state" language)
├─ Feature priority markers ("important", "critical")
└─ Implementation timelines ("will be added", "coming soon")

Prefer:
├─ State descriptions ("exists", "works", "fails")
├─ Component relationships (parent/child)
├─ Decision rationale ("why this approach")
└─ Failure modes ("when this breaks")
```

### Spec Validation Checklist
```
□ No flowcharts (use tree structures)
□ No 'NEW' or priority markers
□ No dates or version numbers (use git history)
□ No unverified performance claims
□ Each section independently comprehensible
□ Token-efficient (avoid prose, use lists)
□ Scannable headings with clear hierarchy
□ Code examples are copy-pasteable
```

---

## 10. Quick Reference

### Common Commands
```
Build full image:
└─ sudo ./assemble-final.sh --board dedede --rootfs full

Build minimal image:
└─ sudo ./assemble-final.sh --board dedede --rootfs minimal

Flash to USB:
└─ sudo ./tools/write-shimboot-image.sh -i work/shimboot.img --output /dev/sdX

Expand rootfs on device:
└─ sudo expand_rootfs

Setup wizard on device:
└─ setup_nixos

Rebuild system on device:
└─ sudo nixos-rebuild switch --flake ~/nixos-config#$(hostname) --option sandbox false
```

### File Paths
```
Configuration:
├─ shimboot_config/user-config.nix           - User settings
├─ shimboot_config/base_configuration/       - Minimal system
└─ shimboot_config/main_configuration/       - Full desktop

Build system:
├─ flake.nix                                 - Main flake
├─ flake_modules/                            - Nix derivations
├─ tools/                                    - Build scripts
└─ bootloader/                               - Shimboot bootloader

Build artifacts:
├─ work/shimboot.img                         - Final disk image
├─ work/harvested/                           - ChromeOS drivers
└─ manifests/${board}-manifest.nix           - Download chunks
```

### Troubleshooting Entry Points
```
Boot hangs at shimboot menu:
└─ Section 6 (Boot Mechanism) → Execution Tree

LightDM fails to start:
└─ Section 7 (Known Constraints) → Software Limitations

WiFi not working:
└─ Section 6 (Boot Mechanism) → Vendor Driver Integration

Build fails:
└─ Section 4 (Build Pipeline) → Reproducibility Matrix

Want to add features:
└─ Section 8 (Extension Points)
```

---

**End of Specification**  
For implementation details, see source files.  
For community support, see GitHub discussions.  
For upstream documentation, see ading2210/shimboot.