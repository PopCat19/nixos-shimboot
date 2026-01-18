# NixOS-Shimboot Modular Refactoring Plan

**Project:** ~/nixos-shimboot
**Date:** 2026-01-18
**Status:** Planning Phase

---

## Current Structure Analysis

### Existing Architecture
```
shimboot_config/
├── user-config.nix                    # Function-based config (needs conversion)
├── base_configuration/
│   ├── configuration.nix              # Base system config
│   └── system_modules/                # 20+ system modules (flat)
└── main_configuration/
    ├── configuration.nix              # Main config wrapper
    ├── system/
    │   └── system_modules/            # 6+ system modules
    └── home/                          # 15+ home modules (flat)
        ├── home.nix                   # Main home entry point
        ├── packages/                  # Package categories
        ├── hypr_config/               # Hyprland config
        └── noctalia_config/           # Noctalia shell config

flake_modules/                         # Flake helper modules
├── raw-image.nix                      # Image generation
├── system-configuration.nix           # System config builder
├── chromeos-sources.nix               # ChromeOS sources
└── patch_initramfs/                   # Initramfs patching

bootloader/                            # Shimboot-specific bootloader
tools/                                 # Build and testing tools
manifests/                             # ChromeOS board manifests
```

### Problem Areas Identified
1. **Flat directories** - 40+ modules across 3 directories
2. **Function-based config** - `user-config.nix` requires parameters
3. **Complex flake structure** - Multiple flake_modules with abstractions
4. **Package fragmentation** - Scattered across multiple files
5. **No host profiles** - Single configuration for all boards

---

## Target Architecture

```
vars/
└── default.nix                        # Plain attribute set (replaces user-config.nix)

lib/
└── default.nix                        # Helper functions (mkHost, etc.)

modules/
├── nixos/
│   ├── core/                          # Base system config
│   │   ├── environment.nix
│   │   ├── boot.nix
│   │   ├── networking.nix
│   │   ├── filesystems.nix
│   │   ├── packages.nix
│   │   ├── security.nix
│   │   ├── systemd-patch.nix
│   │   ├── kill-frecon.nix
│   │   ├── localization.nix
│   │   ├── users.nix
│   │   ├── fish.nix
│   │   ├── services.nix
│   │   └── default.nix
│   ├── desktop/                       # Desktop environment
│   │   ├── display-manager.nix
│   │   ├── xdg-portals.nix
│   │   ├── fonts.nix
│   │   ├── hyprland.nix
│   │   ├── setup-experience.nix
│   │   └── default.nix
│   ├── hardware/                      # Hardware configuration
│   │   ├── hardware.nix
│   │   ├── audio.nix
│   │   ├── power-management.nix
│   │   └── default.nix
│   └── profiles/                      # Hardware profiles
│       ├── shimboot/
│       │   ├── bootloader.nix
│       │   └── default.nix
│       └── board-profiles/
│           ├── dedede.nix
│           ├── octopus.nix
│           └── default.nix
└── home/
    ├── core/                          # Core home config
    │   ├── environment.nix
    │   ├── services.nix
    │   ├── stylix.nix
    │   └── default.nix
    ├── cli/                           # Command-line tools
    │   ├── kitty.nix
    │   ├── fish.nix
    │   ├── micro.nix
    │   ├── fuzzel.nix
    │   ├── fcitx5.nix
    │   └── default.nix
    ├── desktop/                       # Desktop apps
    │   ├── hyprland/
    │   │   ├── hyprland.nix
    │   │   ├── hypr_packages.nix
    │   │   ├── hypr_modules/
    │   │   ├── shaders/
    │   │   └── default.nix
    │   ├── screenshot.nix
    │   ├── kde.nix
    │   ├── dolphin.nix
    │   ├── bookmarks.nix
    │   └── default.nix
    ├── apps/                          # Applications
    │   ├── zen-browser.nix
    │   ├── vesktop.nix
    │   ├── vscodium.nix
    │   ├── privacy.nix
    │   └── default.nix
    └── services/                      # User services
        ├── packages/
        │   ├── communication.nix
        │   ├── media.nix
        │   └── utilities.nix
        └── default.nix

hosts/
├── shimboot/
│   ├── configuration.nix              # Host system config
│   ├── hardware-configuration.nix     # (if exists)
│   └── home.nix                       # Host home config
└── board-configs/
    ├── dedede/
    │   ├── configuration.nix
    │   └── home.nix
    └── octopus/
        ├── configuration.nix
        └── home.nix

# Preserved (unchanged)
flake_modules/                         # Keep as-is for image generation
bootloader/                            # Keep as-is
tools/                                 # Keep as-is
manifests/                             # Keep as-is
```

---

## Refactoring Phases

### Phase 0: Preparation
- [ ] Create backup branch
- [ ] Document current module inventory
- [ ] Identify all dependencies and imports

### Phase 1: Foundation Setup
- [ ] Create `vars/default.nix` from `user-config.nix`
- [ ] Create `lib/default.nix` with helper functions
- [ ] Create new directory structure
- [ ] Verify no circular dependencies

### Phase 2: System Module Migration
- [ ] Move core modules to `modules/nixos/core/`
- [ ] Move desktop modules to `modules/nixos/desktop/`
- [ ] Move hardware modules to `modules/nixos/hardware/`
- [ ] Create category `default.nix` files
- [ ] Create shimboot profile in `modules/nixos/profiles/shimboot/`

### Phase 3: Home Module Migration
- [ ] Move core home modules to `modules/home/core/`
- [ ] Move CLI modules to `modules/home/cli/`
- [ ] Move desktop modules to `modules/home/desktop/`
- [ ] Move app modules to `modules/home/apps/`
- [ ] Move service modules to `modules/home/services/`
- [ ] Create category `default.nix` files

### Phase 4: Host Configuration
- [ ] Create `hosts/shimboot/` directory
- [ ] Create host `configuration.nix`
- [ ] Create host `home.nix`
- [ ] Move board-specific configs to `hosts/board-configs/`

### Phase 5: Flake Simplification
- [ ] Simplify `flake.nix` to use explicit host configs
- [ ] Update `flake_modules/system-configuration.nix` to use new structure
- [ ] Ensure compatibility with existing image generation
- [ ] Test flake outputs

### Phase 6: Package Integration
- [ ] Integrate packages into respective modules
- [ ] Remove standalone package files where appropriate
- [ ] Verify package references are correct

### Phase 7: Cleanup & Validation
- [ ] Remove old `shimboot_config/` directories
- [ ] Run `nix flake check`
- [ ] Dry-build all configurations
- [ ] Fix any errors
- [ ] Format code with `nix fmt`

### Phase 8: Finalization
- [ ] Commit changes
- [ ] Update documentation
- [ ] Test on actual hardware (if possible)

---

## Module Mapping

### System Modules → Categories

#### Core (`modules/nixos/core/`)
- environment.nix
- boot.nix
- networking.nix
- filesystems.nix
- packages.nix
- security.nix
- systemd-patch.nix
- kill-frecon.nix
- localization.nix
- users.nix
- fish.nix
- services.nix
- helpers/helpers.nix

#### Desktop (`modules/nixos/desktop/`)
- display-manager.nix
- xdg-portals.nix
- fonts.nix
- hyprland.nix
- setup-experience.nix

#### Hardware (`modules/nixos/hardware/`)
- hardware.nix
- audio.nix
- power-management.nix

#### Profiles (`modules/nixos/profiles/`)
- shimboot/bootloader.nix (new, from bootloader/ integration)
- board-profiles/dedede.nix (new)
- board-profiles/octopus.nix (new)
- etc.

### Home Modules → Categories

#### Core (`modules/home/core/`)
- environment.nix
- services.nix
- stylix.nix

#### CLI (`modules/home/cli/`)
- kitty.nix
- fish.nix (from system_modules/fish.nix)
- micro.nix
- fuzzel.nix
- fcitx5.nix

#### Desktop (`modules/home/desktop/`)
- hyprland/ (entire directory)
- screenshot.nix
- kde.nix
- dolphin.nix
- bookmarks.nix

#### Apps (`modules/home/apps/`)
- zen-browser.nix
- vesktop.nix
- vscodium.nix
- privacy.nix

#### Services (`modules/home/services/`)
- packages/ (entire directory)
- noctalia_config/ (move to core or keep separate)

---

## Key Decisions

### 1. Preserving Shimboot-Specific Features
- **flake_modules/**: Keep as-is for image generation
- **bootloader/**: Keep as-is, integrate via profile
- **tools/**: Keep as-is
- **manifests/**: Keep as-is

### 2. Host Configuration Strategy
- Create `hosts/shimboot/` as default host
- Create `hosts/board-configs/` for board-specific configs
- Use `lib.mkHost` helper for consistent host creation

### 3. Package Integration
- Move packages into respective modules
- Keep `packages/` subdirectories for large package groups
- Ensure packages are co-located with their configuration

### 4. Backward Compatibility
- Maintain existing flake outputs
- Keep `raw-efi-system` and `nixos-shimboot` aliases
- Ensure image generation still works

---

## Risk Mitigation

### High-Risk Areas
1. **Flake structure changes** - Test thoroughly before committing
2. **Host configuration** - Ensure all specialArgs are preserved
3. **Image generation** - Verify raw-image.nix still works
4. **ChromeOS integration** - Test bootloader and initramfs patching

### Mitigation Strategies
- Create backup branch before starting
- Test each phase independently
- Keep old structure until new structure is verified
- Run `nix flake check` after each phase
- Dry-build all configurations before finalizing

---

## Success Criteria

- [ ] All modules categorized by domain
- [ ] `vars/default.nix` replaces function-based `user-config.nix`
- [ ] Host configurations are minimal and explicit
- [ ] Packages are co-located with their configuration
- [ ] `nix flake check` passes
- [ ] All configurations dry-build successfully
- [ ] Image generation still works
- [ ] No circular dependencies
- [ ] Code is properly formatted

---

## Estimated Module Counts

| Category | Before | After |
|----------|--------|-------|
| System modules | 26 | 3 categories + profiles |
| Home modules | 15 | 5 categories |
| Total directories | 3 | 10+ |
| Files to move | 40+ | 40+ |

---

## Next Steps

1. Review this plan and adjust as needed
2. Create backup branch
3. Begin Phase 1: Foundation Setup
4. Proceed through phases sequentially
5. Validate at each phase

---

**Notes:**
- This plan adapts the REFACTOR_GUIDE.md to shimboot's specific needs
- Shimboot-specific features (bootloader, image generation) are preserved
- The modular structure will make adding new boards easier
- Package locality principle is applied throughout
