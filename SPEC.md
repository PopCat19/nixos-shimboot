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

Supported Boards:
├─ dedede, grunt, hatch, nissa, octopus, snappy, zork
└─ Each board provides: shim, recovery, kernel, initramfs variants
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
   ├─ 1/15: Build Nix outputs
   ├─ 2/15: Harvest ChromeOS drivers
   ├─ 3/15: Augment firmware with upstream linux-firmware
   ├─ 4/15: Prune unused firmware files (conservative Chromebook families)
   │  └─ Enhanced with Chromebook family-specific pruning
   ├─ 5/15: Copy raw rootfs image
   ├─ 6/15: Optimize Nix store
   ├─ 7/15: Calculate partition sizes
   ├─ 8/15: Create empty image
   ├─ 9/15: Partition image (GPT)
   ├─ 10/15: Setup loop device
   ├─ 11/15: Format partitions
   ├─ 12/15: Populate bootloader partition
   ├─ 13/15: Populate rootfs partition
   ├─ 14/15: Clone nixos-config repository
   ├─ 15/15: Inject harvested drivers
   │  ├─ Inputs: raw-rootfs.img, patched-initramfs/, harvested/
   │  ├─ Creates: shimboot.img (partitioned disk image)
   │  └─ Integrates: vendor drivers (vendor/inject/both/none)
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
├─ Running depmod (during harvest)
└─ Pruning firmware files (requires lspci, du)
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
   ├─ audio.nix                     - Audio configuration
   ├─ boot.nix                      - Disables standard bootloaders
   ├─ display.nix                   - LightDM + Hyprland
   ├─ filesystems.nix               - Single ext4 partition
   ├─ fish.nix                      - Fish shell + Starship
   ├─ fish-functions.nix            - Fish shell functions and abbreviations
   ├─ fonts.nix                     - System fonts
   ├─ hardware.nix                  - Firmware enablement
   ├─ localization.nix              - Locale and timezone settings
   ├─ networking.nix                - NetworkManager + wpa_supplicant
   ├─ packages.nix                  - Minimal system packages
   ├─ power-management.nix          - Power management settings
   ├─ security.nix                  - Security configurations
   ├─ services.nix                  - System services
   ├─ systemd.nix                   - Patched systemd + kill-frecon service
   ├─ users.nix                     - Default user accounts
   ├─ zram.nix                      - Swap compression
   ├─ fish_functions/
   │  ├─ fix-fish-history.fish      - History repair utility
   │  ├─ fish-greeting.fish         - Welcome message
   │  ├─ list-fish-helpers.fish     - Function/abbreviation listing
   │  ├─ nixos-flake-update.fish    - Flake update with backup
   │  └─ nixos-rebuild-basic.fish   - System rebuild with kernel checks
   └─ helpers/
      ├─ filesystem-helpers.nix     - expand_rootfs
      ├─ helpers.nix                - Helper scripts entry point
      ├─ permissions-helpers.nix    - permission utilities
      └─ setup-helpers.nix          - setup_nixos wizard

main_configuration/
├─ configuration.nix                - Imports base + adds user modules
├─ system_modules/
   │  ├─ fonts.nix                  - System fonts
   │  ├─ packages.nix               - User applications
   │  └─ services.nix               - Flatpak enablement
│
├─ home_modules/
│  ├─ environment.nix               - Environment variables
│  ├─ fcitx5.nix                    - Input method configuration
│  ├─ fish.nix                      - Shell abbreviations
│  ├─ home.nix                      - Home Manager entry point
│  ├─ kde.nix                       - KDE apps (Dolphin, Gwenview)
│  ├─ kitty.nix                     - Terminal config
│  ├─ lib/
│  │  └─ theme.nix                  - Theme library functions
│  ├─ micro.nix                     - Micro editor configuration
│  ├─ packages/
│  │  ├─ communication.nix         - Vesktop
│  │  ├─ gaming.nix                 - Lutris, OSU
│  │  ├─ media.nix                  - MPV, Audacious
│  │  ├─ notifications.nix          - Notification systems
│  │  └─ utilities.nix              - CLI tools
│  ├─ privacy.nix                   - Privacy settings
│  ├─ programs.nix                  - Program configurations
│  ├─ qt-gtk-config.nix             - Qt/GTK theme configuration
│  ├─ screenshot.fish               - Screenshot function
│  ├─ screenshot.nix                - Screenshot configuration
│  ├─ services.nix                  - User services
│  ├─ starship.nix                  - Starship prompt
│  ├─ theme.nix                     - Rose Pine theming
│  └─ zen-browser.nix               - Browser with extensions
│
├─ hypr_config/
│  ├─ hypr_packages.nix             - Hyprland package definitions
│  ├─ hyprland.nix                  - Hyprland configuration
│  ├─ hyprpanel-common.nix          - HyprPanel common settings
│  ├─ hyprpanel-home.nix            - HyprPanel home configuration
│  ├─ hyprpaper.conf                - Wallpaper configuration
│  ├─ monitors.conf                 - Monitor configuration
│  ├─ userprefs.conf                - User preferences
│  ├─ wallpaper.nix                 - Wallpaper management
│  ├─ hypr_modules/
│  │  ├─ animations.nix            - Window animations
│  │  ├─ autostart.nix              - Autostart applications
│  │  ├─ colors.nix                 - Color scheme
│  │  ├─ environment.nix            - Environment variables
│  │  ├─ fuzzel.nix                 - Application launcher
│  │  ├─ general.nix                - General settings
│  │  ├─ hyprlock.nix               - Lock screen
│  │  ├─ keybinds.nix               - Keyboard shortcuts
│  │  └─ window-rules.nix           - Window behavior rules
│  ├─ shaders/
│  │  ├─ blue-light-filter.glsl     - Blue light filter shader
│  │  └─ cool-stuff.glsl            - Visual effects shader
│  └─ micro_config/
│     └─ rose-pine.micro            - Micro editor theme
│
└─ wallpaper/
   └─ kasane_teto_utau_drawn_by_yananami_numata220.jpg
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

### Kernel Limitations
- Kernels < 5.6: Missing user namespaces; requires `--option sandbox false` for nix operations

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
1. Repository is cloned by assemble-final.sh to /home/{user}/nixos-config
2. Modify configuration in the cloned repository
3. Rebuild with: cd ~/nixos-config && sudo nixos-rebuild switch --flake .#$(hostname)
4. Use setup_nixos for interactive post-install configuration
```

### Setup Script Options
```
setup_nixos [OPTIONS]

Options:
├─ --skip-wifi      Skip Wi-Fi configuration
├─ --skip-expand    Skip root filesystem expansion
├─ --skip-config    Skip nixos-rebuild configuration
├─ --skip-rebuild   Skip system rebuild
├─ --auto           Run in automatic mode with sensible defaults
├─ --debug          Enable debug output
└─ --help, -h       Show help message

Examples:
├─ setup_nixos                    # Interactive mode with all steps
├─ setup_nixos --auto             # Automatic mode
├─ setup_nixos --skip-wifi        # Skip Wi-Fi setup
└─ setup_nixos --debug            # Enable debug logging
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

### Firmware Pruning Configuration
```
Location: tools/harvest-drivers.sh → prune_unused_firmware()

Purpose: Reduce firmware size by conservatively pruning unused files
Timing: After upstream firmware augmentation (step 4/15)

Keep families (board-agnostic Chromebook support):
├─ intel             # Intel WiFi/BT/GPU (most Chromebooks)
├─ iwlwifi           # Intel WiFi (standalone files)
├─ rtw88             # Realtek WiFi (newer)
├─ rtw89             # Realtek WiFi (newest)
├─ brcm              # Broadcom WiFi/BT
├─ ath10k            # Atheros WiFi
├─ mediatek          # MediaTek (new Chromebooks)
├─ regulatory.db     # Required for WiFi
└─ *.ucode           # CPU microcode

Customization:
└─ Edit keep_families array in prune_unused_firmware()
   └─ Add families for specific hardware needs

Disable pruning:
└─ Comment out step 4/15 in assemble-final.sh
   └─ Or set FIRMWARE_UPSTREAM=0 to skip augmentation entirely
```

---

## 9. Maintenance Guide

### When to Update This Spec

**Component Changes:**
```
flake.nix modified
└─ Update: Component Reference section

New configuration module added
└─ Update: Configuration System section

Build process changed
└─ Update: Build Pipeline section

Boot mechanism altered
└─ Update: Boot Mechanism section

Hardware compatibility discovered
└─ Update: Tested Hardware section
          Known Constraints section

New extension point created
└─ Update: Extension Points section
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

Build with explicit board (avoids default warning):
└─ sudo ./assemble-final.sh --board dedede --rootfs full

Build with custom drivers mode:
└─ sudo ./assemble-final.sh --board dedede --rootfs full --drivers vendor

Build without upstream firmware:
└─ sudo ./assemble-final.sh --board dedede --rootfs full --no-firmware-upstream

Flash to USB:
└─ sudo ./tools/write-shimboot-image.sh -i work/shimboot.img --output /dev/sdX
   └─ Uses improved dd flags for better reliability

Expand rootfs on device:
└─ sudo expand_rootfs

Setup wizard on device:
└─ setup_nixos

Rebuild system on device:
└─ sudo nixos-rebuild switch --flake ~/nixos-config#$(hostname) --option sandbox false

Harvest drivers only:
└─ sudo ./tools/harvest-drivers.sh --shim shim.bin --recovery recovery.bin --out drivers/
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
│  ├─ harvest-drivers.sh                     - Driver harvesting with conservative firmware pruning
│  ├─ write-shimboot-image.sh                - USB image writing with improved dd flags
│  └─ fetch-manifest.sh                      - ChromeOS manifest fetching
└─ bootloader/                               - Shimboot bootloader

Build artifacts:
├─ work/shimboot.img                         - Final disk image
├─ work/harvested/                           - ChromeOS drivers (pruned firmware)
├─ work/linux-firmware.upstream/             - Upstream firmware clone
└─ manifests/${board}-manifest.nix           - Download chunks
```

### Troubleshooting Entry Points
```
Boot hangs at shimboot menu:
└─ Boot Mechanism section → Execution Tree

LightDM fails to start:
└─ Known Constraints section → Software Limitations

WiFi not working:
└─ Boot Mechanism section → Vendor Driver Integration

Build fails:
└─ Build Pipeline section → Reproducibility Matrix

Want to add features:
└─ Extension Points section
```

---

**End of Specification**  
For implementation details, see source files.  
For community support, see GitHub discussions.  
For upstream documentation, see ading2210/shimboot.