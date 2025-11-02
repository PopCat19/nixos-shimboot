# NixOS Shimboot Technical Specification

**Status:** Functional (Single Board Verified)  
**Target:** ChromeOS devices with RMA shim vulnerability  
**License:** GPL-3.0 (code) / Unfree (ChromeOS artifacts)

---

## 1. Project Identity

### What This Is
- NixOS distribution bootable via ChromeOS RMA shim exploit
- Declarative system built with Nix flakes
- No firmware modification required
- Boots from USB/SD persistent storage
- Checkpoint-based build system with resume capability
- Integrated binary cache (Cachix)
- CI/CD workflows for automated testing
- Comprehensive error handling and recovery

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
├─ LightDM: Functional
├─ User session: Stable
├─ Audio: Limited/non-functional
├─ Suspend: Not available (kernel limitation)
└─ nixos-rebuild: Requires --option sandbox false on kernels <5.6
```

### Supported Boards (Infrastructure Only)
```
dedede, octopus, zork, nissa, hatch, grunt, snappy
└─ Note: Only dedede fully tested and confirmed working
    └─ Other boards have build infrastructure but require hardware verification
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

### Flake Entry Points
```
flake.nix
├─ packages.${system}
│  ├─ raw-rootfs                    # Full rootfs with Home Manager
│  ├─ raw-rootfs-minimal            # Base rootfs without HM
│  ├─ chromeos-shim-${board}        # Per-board shim
│  ├─ chromeos-recovery-${board}    # Per-board recovery
│  ├─ extracted-kernel-${board}     # Per-board kernel
│  ├─ initramfs-extraction-${board} # Per-board initramfs
│  └─ initramfs-patching-${board}   # Per-board patched initramfs
│
├─ nixosConfigurations
│  ├─ ${hostname}                   # Full system (from user-config.nix)
│  ├─ ${hostname}-minimal           # Minimal system
│  ├─ nixos-shimboot                # Legacy alias for full
│  └─ raw-efi-system                # Legacy alias for minimal
│
└─ devShells.${system}.default      # Development environment
```

### Flake Modules
```
cachix-config.nix
├─ Purpose: Configure Cachix binary cache for all builds
├─ Dependencies: None
├─ Related: flake.nix
└─ Provides: nixConfig with substituters and trusted keys

chromeos-sources.nix
├─ Purpose: ChromeOS source management and recovery URLs
├─ Dependencies: None
├─ Related: flake.nix, manifests/
└─ Provides: chromeos-shim, chromeos-recovery derivations

development-environment.nix
├─ Purpose: Development tools and environment setup
├─ Dependencies: nixpkgs
├─ Related: flake.nix
└─ Provides: devShell with necessary tools

patch_initramfs/
├─ initramfs-extraction.nix
│  ├─ Purpose: Initramfs extraction utilities
│  ├─ Dependencies: kernel-extraction
│  ├─ Related: initramfs-patching.nix
│  └─ Provides: initramfs-extraction derivations
├─ initramfs-patching.nix
│  ├─ Purpose: Initramfs patching utilities
│  ├─ Dependencies: initramfs-extraction, bootloader/
│  ├─ Related: assemble-final.sh
│  └─ Provides: initramfs-patching derivations
└─ kernel-extraction.nix
   ├─ Purpose: Kernel extraction utilities
   ├─ Dependencies: chromeos-sources
   ├─ Related: initramfs-extraction.nix
   └─ Provides: extracted-kernel derivations

raw-image.nix
├─ Purpose: Raw image generation
├─ Dependencies: nixpkgs, nixos-generators
├─ Related: base_configuration/, main_configuration/
└─ Provides: raw-rootfs, raw-rootfs-minimal

system-configuration.nix
├─ Purpose: System configuration utilities
├─ Dependencies: nixpkgs
├─ Related: shimboot_config/
└─ Provides: NixOS configuration utilities
```

### Configuration Structure
```
shimboot_config/
├─ user-config.nix                  # User settings and configuration
├─ base_configuration/
│  ├─ configuration.nix             # Main entry point
│  └─ system_modules/
│     ├─ Core System
│     │  ├─ boot.nix                # Disables standard bootloaders
│     │  ├─ filesystems.nix         # Single ext4 partition
│     │  ├─ hardware.nix            # Firmware enablement
│     │  ├─ localization.nix        # Locale and timezone settings
│     │  ├─ networking.nix          # NetworkManager + wpa_supplicant
│     │  ├─ security.nix            # Security configurations
│     │  ├─ services.nix            # System services
│     │  ├─ systemd.nix             # Patched systemd + kill-frecon
│     │  └─ users.nix               # Default user accounts
│     ├─ Desktop Environment
│     │  ├─ audio.nix               # Audio configuration
│     │  ├─ display-manager.nix     # X server and LightDM
│     │  ├─ hyprland.nix            # Hyprland window manager
│     │  └─ xdg-portals.nix         # XDG portals and desktop integration
│     ├─ User Experience
│     │  ├─ fish.nix                # Fish shell + Starship
│     │  ├─ fonts.nix               # System fonts
│     │  ├─ packages.nix            # Minimal system packages
│     │  └─ power-management.nix    # Power management settings
│     └─ Utilities
│        ├─ helpers/                # Helper scripts
│        ├─ fish_functions/         # Fish shell functions
│        └─ zram.nix                # Swap compression
```

### Build Artifacts (per board)
```
chromeos-shim-${board}
├─ Type: Unfree binary
├─ Source: ChromeOS CDN (manifest-based download)
└─ Contains: Firmware, kernel, initramfs

chromeos-recovery-${board}
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

### Helper Scripts
```
base_configuration/system_modules/helpers/
├─ filesystem-helpers.nix
│  └─ expand_rootfs
│     ├─ Purpose: Expand root partition to full USB capacity
│     ├─ Method: growpart + resize2fs
│     └─ Safety: Interactive confirmation with disk info display
│
├─ setup-helpers.nix
│  ├─ setup_nixos_config
│  │  ├─ Purpose: Configure /etc/nixos for nixos-rebuild
│  │  ├─ Method: Symlink ~/nixos-config/flake.nix to /etc/nixos/
│  │  └─ Validation: Checks for cloned repository
│  │
│  └─ setup_nixos
│     ├─ Purpose: Interactive post-install setup wizard
│     ├─ Options: --skip-wifi, --skip-expand, --skip-config, --skip-rebuild,
│     │          --auto, --config NAME, --debug, --help
│     ├─ Steps:
│     │  1. Wi-Fi configuration (nmcli)
│     │  2. Root filesystem expansion
│     │  3. Git repository update
│     │  4. /etc/nixos configuration
│     │  5. System rebuild (optional)
│     └─ Safety: Backup system, dry-run support, failsafe operations
│
└─ permissions-helpers.nix
   └─ (Placeholder for future utilities)
```

### Fish Functions
```
base_configuration/system_modules/fish_functions/
├─ fish-greeting.fish
│  ├─ Purpose: Minimal, context-aware shell greeting
│  ├─ Features: System info, config status, git branch
│  └─ Caching: Uses fastfetch cache to reduce startup lag
│
├─ nixos-rebuild-basic.fish
│  ├─ Purpose: Perform basic NixOS system rebuild
│  ├─ Abbreviation: nrb
│  ├─ Features: Kernel version check, sandbox compatibility
│  └─ Method: sudo nixos-rebuild switch --flake .
│
├─ nixos-flake-update.fish
│  ├─ Purpose: Update NixOS flake inputs
│  ├─ Abbreviation: flup
│  ├─ Features: Backup flake.lock, show diff, restore on failure
│  └─ Method: nix flake update with kernel compatibility checks
│
├─ fix-fish-history.fish
│  ├─ Purpose: Repair corrupted Fish history files
│  ├─ Method: history merge with fallback to manual truncation
│  └─ Safety: Creates backup before repair
│
└─ list-fish-helpers.fish
   ├─ Purpose: Display available Fish functions and abbreviations
   └─ Output: Sorted list of custom functions and abbreviations
```

### Build System Features
```
assemble-final.sh v2.0
├─ Checkpoint System
│  ├─ Save/load build state at each step
│  ├─ Resume from last completed step
│  └─ --fresh flag to ignore checkpoints
│
├─ Error Handling
│  ├─ Step-specific error messages with troubleshooting
│  ├─ Automatic cleanup on failure
│  └─ Retry logic for Nix builds
│
├─ CI Integration
│  ├─ Auto-detection: GITHUB_ACTIONS, GITLAB_CI, JENKINS_HOME
│  ├─ Conditional NIX_BUILD_FLAGS
│  └─ Enhanced logging for CI environments
│
├─ Cache Management
│  ├─ verify_cachix_config() - Pre-build cache verification
│  ├─ show_cache_stats() - Post-build statistics
│  ├─ --prewarm-cache - Fetch from cache before building
│  └─ --pull-cached-image - Use pre-built image from cache
│
├─ Safety Features
│  ├─ --dry-run mode for testing
│  ├─ safe_exec wrapper for destructive operations
│  ├─ Loop device cleanup on exit
│  └─ Partition validation after formatting
│
├─ Build Metadata
│  ├─ JSON output at /etc/shimboot-build.json
│  ├─ Fields: build_date, board, rootfs_flavor, drivers_mode,
│  │         git_commit, nix_version, image_size_mb
│  └─ Clones nixos-config to /home/{user}/nixos-config with branch info
│
└─ Progress Tracking
   ├─ 15 distinct build steps with clear labels
   ├─ Progress bar for long operations
   └─ Disk space checks before building
```

### Write Script Features
```
write-shimboot-image.sh
├─ Safety Features
│  ├─ Automatic system disk detection and exclusion
│  ├─ Interactive device selection with validation
│  ├─ Automatic unmounting of target device partitions
│  ├─ Size validation and large device warnings (>128GiB)
│  └─ Countdown timer before write (default: 10s)
│
├─ Device Listing
│  ├─ --list: Show safe candidate devices (unmounted, non-system)
│  ├─ --list-all: Show all disks with MNT/SYS/IGN markers
│  └─ Color-coded: RED=system, YELLOW=mounted, MAGENTA=ignored
│
├─ UDisks Integration
│  ├─ Detects UDisks-managed mounts (uhelper=udisks2)
│  ├─ Shows mounts under /run/media and /media
│  └─ Automatic unmount via udisksctl before write
│
├─ Options
│  ├─ -i, --input PATH        Input image path
│  ├─ -o, --output DEVICE     Output block device
│  ├─ --yes                   Skip countdown confirmation
│  ├─ --countdown N           Confirmation seconds (default: 10)
│  ├─ --dry-run               Show what would be done
│  ├─ --auto-unmount          Try to unmount target (default)
│  ├─ --no-auto-unmount       Abort if mounted
│  ├─ --force-part            Allow writing to partition
│  ├─ --ignore LIST           Comma-separated devices to hide
│  ├─ --ignore-file PATH      File with device names to hide
│  └─ --allow-large           Skip confirmation for >128GiB devices
│
└─ Write Method
   ├─ dd with 4M block size
   ├─ status=progress for visual feedback
   ├─ conv=fdatasync for data integrity
   └─ oflag=direct for better performance
```

### Utility Scripts
```
tools/
├─ check-cachix.sh
│  ├─ Purpose: Check Cachix cache health and coverage
 │  ├─ Input: main_configuration/, home-manager
 │  ├─ Output: nixos.img (ext4 filesystem)
 │  └─ Generator: nixos-generators (raw format)
 │
├─ cleanup-shimboot-rootfs.sh
│  ├─ Purpose: Prune old shimboot rootfs generations
│  ├─ Discovery: Nix profile, GC roots, result* symlinks
│  ├─ Options: --keep N, --dry-run, --no-dry-run
│  └─ Safety: Backup critical files, dry-run by default
│
├─ collect-minimal-logs.sh
│  ├─ Purpose: Collect diagnostics from minimal rootfs
│  ├─ Method: Mount rootfs read-only, extract logs
│  ├─ Logs: LightDM, Xorg, journal, PAM, user configs
│  └─ Safety: Auto-unmount, cleanup on exit
│
├─ fetch-manifest.sh
│  ├─ Purpose: Download ChromeOS recovery image manifest
│  ├─ Method: Fetch JSON from CDN, download chunks in parallel
│  ├─ Options: --jobs N, --path FILE, --regenerate, --fixup
│  └─ Output: manifests/${board}-manifest.nix
│
├─ fetch-recovery.sh
│  ├─ Purpose: Automate fetching ChromeOS recovery image hashes
│  ├─ Sources: ChromeOS releases JSON, Google recovery API
│  ├─ Options: --skip-wifi, --board BOARD, --dry-run, --debug
│  └─ Updates: flake_modules/chromeos-sources.nix
│
├─ harvest-drivers.sh
│  ├─ Purpose: Extract ChromeOS drivers from shim/recovery
│  ├─ Method: Mount images read-only, copy lib/{modules,firmware}
│  ├─ Features: Firmware pruning, symlink dereferencing
│  └─ Output: lib/modules, lib/firmware, modprobe.d
│
└─ test-board-builds.sh
   ├─ Purpose: Test flake builds for all supported boards
   ├─ Method: Build chromeos-shim package per board
   ├─ Options: --json for machine-readable output
   └─ Output: Build success/failure summary
```

### Home Manager Integration (main_configuration only)
```
main_configuration/home_modules/
├─ home.nix                          # Entry point
├─ packages.nix                      # User applications
├─ programs.nix                      # Program configurations
├─ services.nix                      # User services
├─ environment.nix                   # Environment variables
├─ theme.nix                         # Rose Pine theming
├─ qt-gtk-config.nix                 # Qt/GTK theme configuration
├─ privacy.nix                       # Privacy settings
├─ packages/
│  ├─ communication.nix              # Vesktop
│  ├─ gaming.nix                     # Lutris, OSU
│  ├─ media.nix                      # MPV, Audacious
│  ├─ notifications.nix              # Notification systems
│  └─ utilities.nix                  # CLI tools
├─ kde.nix                           # KDE apps (Dolphin, Gwenview)
├─ kitty.nix                         # Terminal config
├─ micro.nix                         # Micro editor configuration
├─ zen-browser.nix                   # Browser with extensions
├─ fcitx5.nix                        # Input method configuration
├─ fish-themes.nix                   # Fish shell themes
├─ screenshot.fish                   # Screenshot function
└─ screenshot.nix                    # Screenshot configuration
```

### Hyprland Configuration (main_configuration only)
```
main_configuration/hypr_config/
├─ hyprland.nix                      # Hyprland configuration
├─ hypr_modules/
│  ├─ animations.nix                # Window animations
│  ├─ autostart.nix                 # Autostart applications
│  ├─ colors.nix                    # Color scheme
│  ├─ environment.nix               # Environment variables
│  ├─ fuzzel.nix                    # Application launcher
│  ├─ general.nix                   # General settings
│  ├─ hyprlock.nix                  # Lock screen
│  ├─ keybinds.nix                  # Keyboard shortcuts
│  └─ window-rules.nix              # Window behavior rules
├─ hypr_packages.nix                 # Hyprland package definitions
├─ hyprpanel-common.nix              # HyprPanel common settings
├─ hyprpanel-home.nix                # HyprPanel home configuration
├─ hyprpaper.conf                    # Wallpaper configuration
├─ monitors.conf                     # Monitor configuration
├─ shaders/
│  ├─ blue-light-filter.glsl        # Blue light filter shader
│  └─ cool-stuff.glsl               # Visual effects shader
├─ userprefs.conf                    # User preferences
└─ wallpaper.nix                     # Wallpaper management
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
 └─ assemble-final.sh v2.0 (imperative with enhanced features)
    ├─ Pre-build: Cache verification and optional prewarming
    │  ├─ verify_cachix_config() - Check cache setup before builds
    │  ├─ show_cache_stats() - Display build cache statistics
    │  └─ --prewarm-cache option - Fetch from cache before building
    ├─ 1/15: Build Nix outputs (with retry logic and CI flags)
    │  ├─ Conditional NIX_BUILD_FLAGS for CI vs local environments
    │  ├─ JSON build metadata at /etc/shimboot-build.json
    │  └─ Comprehensive error handling with safe_exec wrapper
    ├─ 1/15 (Cachix): Push built derivations to cache (enhanced CI detection)
    ├─ 2/15: Harvest ChromeOS drivers (with comprehensive error handling)
    ├─ 3/15: Augment firmware with upstream ChromiumOS linux-firmware
    ├─ 4/15: Prune unused firmware files (robust path resolution)
    ├─ 5/15: Calculate vendor partition size after firmware merge
    ├─ 6/15: Copy raw rootfs image (progress indication with pv)
    ├─ 7/15: Optimize Nix store in raw rootfs
    ├─ 8/15: Calculate rootfs size
    ├─ 9/15: Create empty image (with --dry-run support)
    ├─ 10/15: Partition image (GPT, ChromeOS GUIDs, vendor before rootfs)
    ├─ 11/15: Setup loop device
    ├─ 12/15: Format partitions + verification
    ├─ 13/15: Populate bootloader partition
    ├─ 14/15: Populate rootfs partition (now p5)
    │  └─ Clone nixos-config repository into rootfs (dynamic remote detection)
    ├─ 15/15: Handle driver placement strategy (refactored functions)
    │  ├─ Modes: vendor|inject|both|none
    │  ├─ Functions: populate_vendor(), inject_drivers()
    │  ├─ Inputs: raw-rootfs.img, patched-initramfs/, harvested/
    │  ├─ Creates: shimboot.img (partitioned disk image)
    │  └─ Integrates: vendor drivers (separate partition or injected)
    ├─ Sync: Final Cachix push sync (enhanced CI detection)
    └─ (optional) Cleanup: Prune older shimboot rootfs generations
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
shimboot_config/
├─ user-config.nix                  - User settings and configuration
├─ base_configuration/
│  ├─ configuration.nix             - Main entry point
│  └─ system_modules/
│     ├─ audio.nix                  - Audio configuration
│     ├─ boot.nix                   - Disables standard bootloaders
│     ├─ display-manager.nix        - X server and LightDM
│     ├─ filesystems.nix            - Single ext4 partition
│     ├─ fish.nix                   - Fish shell + Starship
│     ├─ fonts.nix                  - System fonts
│     ├─ hardware.nix               - Firmware enablement
│     ├─ hyprland.nix               - Hyprland window manager
│     ├─ localization.nix           - Locale and timezone settings
│     ├─ networking.nix             - NetworkManager + wpa_supplicant
│     ├─ packages.nix               - Minimal system packages
│     ├─ power-management.nix       - Power management settings
│     ├─ security.nix               - Security configurations
│     ├─ services.nix               - System services
│     ├─ systemd.nix                - Patched systemd + kill-frecon service
│     ├─ users.nix                  - Default user accounts
│     ├─ xdg-portals.nix            - XDG portals and desktop integration
│     ├─ zram.nix                   - Swap compression
│     ├─ fish_functions/
│     │  ├─ fish-greeting.fish      - Welcome message
│     │  ├─ fix-fish-history.fish   - History repair utility
│     │  ├─ list-fish-helpers.fish  - Function/abbreviation listing
│     │  ├─ nixos-flake-update.fish - Flake update with backup
│     │  └─ nixos-rebuild-basic.fish - System rebuild with kernel checks
│     └─ helpers/
│        ├─ filesystem-helpers.nix  - expand_rootfs
│        ├─ helpers.nix             - Helper scripts entry point
│        ├─ permissions-helpers.nix - permission utilities
│        └─ setup-helpers.nix       - setup_nixos wizard
├─ main_configuration/
│  ├─ configuration.nix             - Imports base + adds user modules
│  ├─ home_modules/
│  │  ├─ environment.nix            - Environment variables
│  │  ├─ fcitx5.nix                 - Input method configuration
│  │  ├─ fish-themes.nix            - Fish shell themes
│  │  ├─ home.nix                   - Home Manager entry point
│  │  ├─ kde.nix                    - KDE apps (Dolphin, Gwenview)
│  │  ├─ kitty.nix                  - Terminal config
│  │  ├─ lib/
│  │  │  └─ theme.nix               - Theme library functions
│  │  ├─ micro.nix                  - Micro editor configuration
│  │  ├─ packages/
│  │  │  ├─ communication.nix       - Vesktop
│  │  │  ├─ gaming.nix              - Lutris, OSU
│  │  │  ├─ media.nix               - MPV, Audacious
│  │  │  ├─ notifications.nix       - Notification systems
│  │  │  └─ utilities.nix           - CLI tools
│  │  ├─ packages.nix               - User applications
│  │  ├─ privacy.nix                - Privacy settings
│  │  ├─ programs.nix               - Program configurations
│  │  ├─ qt-gtk-config.nix          - Qt/GTK theme configuration
│  │  ├─ screenshot.fish            - Screenshot function
│  │  ├─ screenshot.nix             - Screenshot configuration
│  │  ├─ services.nix               - User services
│  │  ├─ theme.nix                  - Rose Pine theming
│  │  └─ zen-browser.nix            - Browser with extensions
│  ├─ hypr_config/
│  │  ├─ hyprland.nix               - Hyprland configuration
│  │  ├─ hypr_modules/
│  │  │  ├─ animations.nix         - Window animations
│  │  │  ├─ autostart.nix          - Autostart applications
│  │  │  ├─ colors.nix             - Color scheme
│  │  │  ├─ environment.nix        - Environment variables
│  │  │  ├─ fuzzel.nix             - Application launcher
│  │  │  ├─ general.nix            - General settings
│  │  │  ├─ hyprlock.nix           - Lock screen
│  │  │  ├─ keybinds.nix           - Keyboard shortcuts
│  │  │  └─ window-rules.nix       - Window behavior rules
│  │  ├─ hyprland.nix               - Hyprland configuration
│  │  ├─ hypr_packages.nix          - Hyprland package definitions
│  │  ├─ hyprpanel-common.nix       - HyprPanel common settings
│  │  ├─ hyprpanel-home.nix         - HyprPanel home configuration
│  │  ├─ hyprpaper.conf             - Wallpaper configuration
│  │  ├─ micro_config/
│  │  │  └─ rose-pine.micro        - Micro editor theme
│  │  ├─ monitors.conf              - Monitor configuration
│  │  ├─ shaders/
│  │  │  ├─ blue-light-filter.glsl - Blue light filter shader
│  │  │  └─ cool-stuff.glsl        - Visual effects shader
│  │  ├─ userprefs.conf             - User preferences
│  │  └─ wallpaper.nix              - Wallpaper management
│  └─ wallpaper/
│     └─ kasane_teto_utau_drawn_by_yananami_numata220.jpg
└─ fish_themes/
   ├─ Rosé Pine Dawn.theme
   ├─ Rosé Pine Moon.theme
   └─ Rosé Pine.theme

Project Structure:
├─ bootloader/
│  ├─ bin/
│  │  ├─ bootstrap.sh               - Bootloader entry point
│  │  └─ init                       - BusyBox init replacement
│  └─ opt/
│     ├─ crossystem                 - ChromeOS system tools
│     └─ mount-encrypted            - LUKS decryption helper
├─ flake_modules/
│  ├─ cachix-config.nix             - Cachix binary cache configuration
│  ├─ chromeos-sources.nix          - ChromeOS source management
│  ├─ development-environment.nix   - Development environment setup
│  ├─ patch_initramfs/
│  │  ├─ initramfs-extraction.nix   - Initramfs extraction utilities
│  │  ├─ initramfs-patching.nix     - Initramfs patching utilities
│  │  └─ kernel-extraction.nix      - Kernel extraction utilities
│  ├─ raw-image.nix                 - Raw image generation
│  └─ system-configuration.nix      - System configuration utilities
├─ llm-notes/
│  ├─ commenting-conventions.md     - Code commenting and documentation standards
│  └─ development-workflow.md       - Development workflow and practices
├─ manifests/                       - ChromeOS board manifests
│  ├─ dedede-manifest.nix
│  ├─ grunt-manifest.nix
│  ├─ hatch-manifest.nix
│  ├─ nissa-manifest.nix
│  ├─ octopus-manifest.nix
│  ├─ snappy-manifest.nix
│  └─ zork-manifest.nix
├─ overlays/                        - Custom package overlays
│  ├─ overlays.nix                  - Package overlay definitions
│  └─ rose-pine-gtk-theme-full.nix  - GTK theme overlay
├─ snapshots/                       - Project state snapshots
│  ├─ project-state-2025-10-23T15:20:16.151Z.md
│  ├─ project-state-2025-10-23T18:18:51.852Z.md
│  └─ project-state-2025-10-24T09:28:50.503Z.md
└─ tools/                           - Build and utility scripts
   ├─ check-cachix.sh               - Cache health monitoring
   ├─ cleanup-shimboot-rootfs.sh    - Rootfs cleanup utilities
   ├─ collect-minimal-logs.sh       - Log collection
   ├─ compress-nix-store.sh         - Nix store compression
   ├─ fetch-manifest.sh             - ChromeOS manifest fetching
   ├─ fetch-recovery.sh             - Recovery image fetching
   ├─ harvest-drivers.sh            - Driver harvesting with firmware pruning
   └─ test-board-builds.sh          - Board-specific build testing
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
Method: Keep firmware for known Chromebook families (intel, iwlwifi, rtw88, rtw89, brcm, ath10k, mediatek, regulatory.db, *.ucode)

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

### Cache Management and CI Integration

#### Cachix Configuration
```
Location: flake_modules/cachix-config.nix

Purpose: Centralized binary cache configuration for all builds
Features:
├─ Configures Nix substituters for binary cache access
├─ Sets up trusted public keys for cache verification
├─ Enables faster builds through cache reuse
└─ Automatically imported by flake.nix

Cache endpoints:
├─ https://cache.nixos.org (official NixOS cache)
└─ https://shimboot-systemd-nixos.cachix.org (project-specific cache)
```

#### Cache Health Monitoring
```
Tool: tools/check-cachix.sh

Purpose: Check Cachix cache health and coverage for shimboot derivations
Usage: ./tools/check-cachix.sh [BOARD]

Features:
├─ Cache endpoint connectivity testing
├─ Cache coverage verification for board-specific derivations
├─ Derivation availability checking (cached vs needs build)
└─ Board-specific cache analysis

Example output:
├─ chromeos-shim-dedede     ... CACHED ✓
├─ extracted-kernel-dedede  ... MISSING ✗
├─ initramfs-patching-dedede ... CACHED ✓
└─ raw-rootfs               ... CACHED ✓
```

#### Enhanced Build Features
```
Cache Management Options:
├─ --prewarm-cache     - Fetch from cache before building
├─ verify_cachix_config() - Check cache setup before builds
└─ show_cache_stats() - Display build cache statistics

CI Integration Features:
├─ Conditional NIX_BUILD_FLAGS for CI vs local environments
├─ Enhanced CI detection for multiple CI environments
├─ JSON build metadata at /etc/shimboot-build.json
└─ Retry logic for Nix build commands

Dry-run Mode:
├─ --dry-run option for safe testing
├─ safe_exec wrapper for all destructive operations
└─ No actual filesystem modifications

Build Metadata (JSON):
├─ git_commit      - Current commit hash
├─ build_timestamp - Build start time
├─ board          - Target board
├─ rootfs_type    - minimal|full
├─ drivers_mode   - vendor|inject|both|none
├─ image_size     - Final image size in bytes
└─ cache_hits     - Number of derivations from cache
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

Build with inspection after completion:
└─ sudo ./assemble-final.sh --board dedede --rootfs full --inspect

Build with cleanup options:
└─ sudo ./assemble-final.sh --board dedede --rootfs full --cleanup-rootfs --cleanup-keep 2 --no-dry-run

Build with vendor drivers and cleanup:
└─ sudo ./assemble-final.sh --board dedede --rootfs minimal --drivers vendor --cleanup-rootfs --cleanup-keep 2 --no-dry-run

Build with cache management options:
└─ sudo ./assemble-final.sh --board dedede --rootfs full --prewarm-cache

Build in dry-run mode (safe for testing):
└─ sudo ./assemble-final.sh --board dedede --rootfs full --dry-run

Check cache health before building:
└─ ./tools/check-cachix.sh dedede

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
├─ assemble-final.sh                         - Main build script v2.0 with enhanced features
├─ flake.nix                                 - Main flake
├─ bootloader/                               - Shimboot bootloader
│  ├─ bin/bootstrap.sh                       - Bootloader entry point
│  ├─ bin/init                               - BusyBox init replacement
│  └─ opt/
│     ├─ crossystem                          - ChromeOS system tools
│     └─ mount-encrypted                     - LUKS decryption helper
├─ flake_modules/                            - Nix derivations
│  ├─ cachix-config.nix                      - Cachix binary cache configuration
│  ├─ chromeos-sources.nix                   - ChromeOS source management
│  ├─ development-environment.nix            - Development tools and environment
│  ├─ patch_initramfs/
│  │  ├─ initramfs-extraction.nix            - Initramfs extraction utilities
│  │  ├─ initramfs-patching.nix              - Initramfs patching utilities
│  │  └─ kernel-extraction.nix               - Kernel extraction utilities
│  ├─ raw-image.nix                          - Raw image generation
│  └─ system-configuration.nix               - System configuration utilities
├─ llm-notes/                                - Documentation and conventions
│  ├─ commenting-conventions.md              - Code commenting standards
│  └─ development-workflow.md                - Development workflow
├─ manifests/                                - ChromeOS board manifests
│  ├─ dedede-manifest.nix
│  ├─ grunt-manifest.nix
│  ├─ hatch-manifest.nix
│  ├─ nissa-manifest.nix
│  ├─ octopus-manifest.nix
│  ├─ snappy-manifest.nix
│  └─ zork-manifest.nix
├─ overlays/                                 - Custom package overlays
│  ├─ overlays.nix                           - Package overlay definitions
│  └─ rose-pine-gtk-theme-full.nix           - GTK theme overlay
├─ snapshots/                                - Project state snapshots
│  ├─ project-state-2025-10-23T15:20:16.151Z.md
│  ├─ project-state-2025-10-23T18:18:51.852Z.md
│  └─ project-state-2025-10-24T09:28:50.503Z.md
└─ tools/                                    - Build and utility scripts
   ├─ check-cachix.sh                        - Cache health monitoring
   ├─ cleanup-shimboot-rootfs.sh             - Rootfs cleanup utilities
   ├─ collect-minimal-logs.sh                - Log collection
   ├─ compress-nix-store.sh                  - Nix store compression
   ├─ fetch-manifest.sh                      - ChromeOS manifest fetching
   ├─ fetch-recovery.sh                      - Recovery image fetching
   ├─ harvest-drivers.sh                     - Driver harvesting with conservative firmware pruning
   └─ test-board-builds.sh                   - Board-specific build testing

Build artifacts:
├─ work/shimboot.img                         - Final disk image
├─ work/harvested/                           - ChromeOS drivers (pruned firmware)
├─ work/linux-firmware.upstream/             - Upstream firmware clone
├─ /etc/shimboot-build.json                  - Build metadata (JSON format)
└─ manifests/${board}-manifest.nix           - Download chunks

Working directories:
├─ work/mnt_bootloader                       - Bootloader mount point
├─ work/mnt_rootfs                           - Rootfs mount point
└─ work/mnt_src_rootfs                       - Source rootfs mount point

Development files:
├─ quickstart.md                             - Quick start guide
├─ README.md                                 - Project documentation
├─ LICENSE                                   - License file
└─ SPEC.md                                   - Technical specification (this file)
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

Cache issues:
└─ Cache Management and CI Integration section → Cache Health Monitoring

CI build problems:
└─ Cache Management and CI Integration section → Enhanced Build Features

Dry-run mode not working:
└─ Cache Management and CI Integration section → Dry-run Mode

Build metadata missing:
└─ Cache Management and CI Integration section → Build Metadata

Want to add features:
└─ Extension Points section
```

---

**End of Specification**  
For implementation details, see source files.  
For community support, see GitHub discussions.  
For upstream documentation, see ading2210/shimboot.