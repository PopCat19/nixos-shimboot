# NixOS-Shimboot Modular Refactoring Guide

**Project:** ~/nixos-shimboot
**Purpose:** Guide for converting flat-file architecture to categorical-modular architecture
**Based On:** The modular refactor methodology from nixos-config
**Date:** 2026-01-17

---

## Executive Summary

**Current State Analysis**

The nixos-shimboot project follows the classic flat-file pattern:
- Centralized `user-config.nix` with function-based configuration
- `shimboot_config/base_configuration/` with 30+ system modules
- `shimboot_config/main_configuration/` with 30+ home modules
- Fragmented package definitions across multiple files

**Refactor Goal**

Convert to categorical-modular architecture to:
- Eliminate Nix-debt (adding features = minimal changes)
- Improve discoverability (find configs by domain, not file name)
- Enable scalability (easy to add new hosts)
- Apply locality principle (packages with their configs)

---

## Phase 0: Analysis & Planning

### 0.1 Document Current Structure

```bash
# Count current modules
find shimboot_config/base_configuration/system_modules -name "*.nix" | wc -l
find shimboot_config/main_configuration/home -name "*.nix" | wc -l

# List categories
ls shimboot_config/base_configuration/system_modules
ls shimboot_config/main_configuration/home
ls shimboot_config/main_configuration/home/system_modules
```

**Current Module Counts (Estimated):**
- System modules: ~30 files
- Home modules: ~20 files
- Package files: Scattered across multiple locations

### 0.2 Identify Problem Areas

| Issue | Impact | Example |
|--------|---------|----------|
| Flat directories | Hard to navigate | 60+ files in 2 directories |
| Package fragmentation | Unclear where packages installed | packages split across multiple files |
| Function-based config | Complex, error-prone | `user-config.nix` requires function arguments |
| No hardware profiles | Repetition between devices | Device-specific rules in multiple places |
| Complex flake.nix | Abstractions hide host details | `flake_modules/` with helper functions |

### 0.3 Create Backup Branch

```bash
cd ~/nixos-shimboot
git checkout -b refactor-backup-$(date +%Y%m%d)
git add -A
git commit -m "Pre-refactor backup: flat-file architecture"
```

---

## Phase 1: Foundation Setup

### 1.1 Create New Directory Structure

```bash
# Create foundation directories
mkdir -p vars
mkdir -p lib

# Create categorized module directories
mkdir -p modules/nixos/core
mkdir -p modules/nixos/desktop
mkdir -p modules/nixos/hardware
mkdir -p modules/nixos/services
mkdir -p modules/nixos/profiles
mkdir -p modules/nixos/gaming

mkdir -p modules/home/cli
mkdir -p modules/home/desktop
mkdir -p modules/home/apps
mkdir -p modules/home/services
mkdir -p modules/home/core
mkdir -p modules/home/ai
```

### 1.2 Extract Variables to `vars/default.nix`

**Current:** `user-config.nix` is a function with arguments

```nix
# Current user-config.nix (function-based)
{ hostname, system, username, machine }: {
  # ... complex nested config ...
}
```

**Target:** Convert to plain attribute set

```nix
# vars/default.nix - Plain attribute set
{
  # User information
  username = "YOUR_USERNAME";  # Replace with your username
  
  # System configuration
  system = "x86_64-linux";  # or your architecture
  
  # Host configuration
  host = {
    hostname = "shimboot";  # Default hostname
  };
  
  # Directory paths
  directories = {
    home = "/home/${vars.username}";
    # Add your custom directories
  };
  
  # Theme configuration
  theme = {
    hue = 0;  # Replace with your theme hue
    variant = "dark";  # or "light"
  };
  
  # Font configuration
  fonts = {
    monospace = {
      packageName = "fira-code";
      name = "FiraCode Nerd Font";
      size = 10;
    };
    # Add other fonts
  };
  
  # Default applications
  defaultApps = {
    terminal = {
      package = "kitty";
      command = "kitty";
    };
    editor = {
      package = "micro";
      command = "micro";
    };
    # Add your applications
  };
  
  # Git configuration
  git = {
    userName = "Your Name";
    userEmail = "your.email@example.com";
    extraConfig = { };
  };
}
```

**Key Changes:**
- ✅ Remove function wrapper
- ✅ Keep only attribute set content
- ✅ Add all commonly used values as top-level keys

### 1.3 Create Helper Functions in `lib/default.nix`

```nix
# lib/default.nix - Helper Functions
{
  mkHost = hostname: extraModules:
    { inputs, nixpkgs, vars, hostName ? hostname }:
    nixpkgs.lib.nixosSystem {
      system = vars.system;  # Use from vars instead of hardcoded
      specialArgs = { inherit inputs vars hostName; };
      modules = [
        ./hosts/${hostname}/configuration.nix
        inputs.home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.extraSpecialArgs = { inherit inputs vars hostName; };
          home-manager.users.${vars.username} = {
            imports = [ ./hosts/${hostname}/home.nix ];
          };
        }
      ] ++ extraModules;
    };
}
```

---

## Phase 2: System Module Refactoring

### 2.1 Map Current Modules to Categories

**From:** `shimboot_config/base_configuration/system_modules/`

| Category | Purpose | Example Modules (Check your files) |
|----------|---------|----------------------------------|
| **Core** | Base system config | `environment.nix`, `boot.nix`, `networking.nix`, `localization.nix`, `users.nix`, `fish.nix` |
| **Desktop** | Display, fonts, greeters | `display.nix`, `fonts.nix`, `greeter.nix`, `display-manager.nix` |
| **Hardware** | Drivers, peripherals | `hardware.nix`, `audio.nix`, `bluetooth.nix`, `tablet.nix`, `power-management.nix` |
| **Services** | System services | `ssh.nix`, `syncthing.nix`, `virtualization.nix`, `vpn.nix` |

### 2.2 Move Core Modules

```bash
cd ~/nixos-shimboot

# Move core modules
mv shimboot_config/base_configuration/system_modules/environment.nix modules/nixos/core/
mv shimboot_config/base_configuration/system_modules/boot.nix modules/nixos/core/
mv shimboot_config/base_configuration/system_modules/networking.nix modules/nixos/core/
mv shimboot_config/base_configuration/system_modules/localization.nix modules/nixos/core/
mv shimboot_config/base_configuration/system_modules/users.nix modules/nixos/core/
mv shimboot_config/base_configuration/system_modules/fish.nix modules/nixos/core/
mv shimboot_config/base_configuration/system_modules/packages.nix modules/nixos/core/
```

Create `modules/nixos/core/default.nix`:

```nix
{
  imports = [
    ./environment.nix
    ./boot.nix
    ./networking.nix
    ./localization.nix
    ./users.nix
    ./fish.nix
    ./packages.nix
  ];
}
```

### 2.3 Move Desktop Modules

```bash
# Move desktop modules
mv shimboot_config/base_configuration/system_modules/display.nix modules/nixos/desktop/
mv shimboot_config/base_configuration/system_modules/fonts.nix modules/nixos/desktop/
mv shimboot_config/base_configuration/system_modules/greeter.nix modules/nixos/desktop/
mv shimboot_config/base_configuration/system_modules/display-manager.nix modules/nixos/desktop/
```

Create `modules/nixos/desktop/default.nix`:

```nix
{
  imports = [
    ./display.nix
    ./fonts.nix
    ./greeter.nix
    ./display-manager.nix
  ];
}
```

### 2.4 Move Hardware Modules

```bash
# Move hardware modules
mv shimboot_config/base_configuration/system_modules/hardware.nix modules/nixos/hardware/
mv shimboot_config/base_configuration/system_modules/audio.nix modules/nixos/hardware/
mv shimboot_config/base_configuration/system_modules/bluetooth.nix modules/nixos/hardware/
mv shimboot_config/base_configuration/system_modules/tablet.nix modules/nixos/hardware/
mv shimboot_config/base_configuration/system_modules/power-management.nix modules/nixos/hardware/
```

Create `modules/nixos/hardware/default.nix`:

```nix
{
  imports = [
    ./hardware.nix
    ./audio.nix
    ./bluetooth.nix
    ./tablet.nix
    ./power-management.nix
  ];
}
```

### 2.5 Move Services Modules

```bash
# Move service modules
mv shimboot_config/base_configuration/system_modules/ssh.nix modules/nixos/services/
mv shimboot_config/base_configuration/system_modules/syncthing.nix modules/nixos/services/
mv shimboot_config/base_configuration/system_modules/virtualization.nix modules/nixos/services/
mv shimboot_config/base_configuration/system_modules/vpn.nix modules/nixos/services/
```

Create `modules/nixos/services/default.nix`:

```nix
{
  imports = [
    ./ssh.nix
    ./syncthing.nix
    ./virtualization.nix
    ./vpn.nix
  ];
}
```

### 2.6 Create Hardware Profiles

If you have device-specific modules in `shimboot_config/base_configuration/`:

```bash
# Create device profile directories
mkdir -p modules/nixos/profiles/shimboot
mkdir -p modules/nixos/profiles/test-board

# Move device-specific modules
mv shimboot_config/base_configuration/modules/shimboot.nix modules/nixos/profiles/shimboot/
mv shimboot_config/base_configuration/modules/test-board.nix modules/nixos/profiles/test-board/
```

Create `modules/nixos/profiles/shimboot/default.nix`:

```nix
{
  imports = [
    ./shimboot.nix
  ];
}
```

---

## Phase 3: Home Module Refactoring

### 3.1 Map Current Modules to Categories

**From:** `shimboot_config/main_configuration/home/`

| Category | Purpose | Example Modules (Check your files) |
|----------|---------|----------------------------------|
| **CLI** | Terminal, shell, command-line tools | `fish.nix`, `kitty.nix`, `micro.nix`, `starship.nix`, `fuzzel.nix` |
| **Desktop** | Desktop environment, launcher | `hyprland.nix`, `screenshot.nix`, `launcher.nix`, `audio-control.nix` |
| **Apps** | Applications (browser, editors, Discord) | `browser.nix`, `editor.nix`, `discord.nix` |
| **Services** | User services, background apps | `syncthing.nix`, `ollama.nix`, `privacy.nix` |
| **Core** | Home configuration base | `stylix.nix`, `fonts.nix`, `environment.nix`, `xdg.nix` |

### 3.2 Move CLI Modules

```bash
# Move CLI modules
mv shimboot_config/main_configuration/home/fish.nix modules/home/cli/
mv shimboot_config/main_configuration/home/kitty.nix modules/home/cli/
mv shimboot_config/main_configuration/home/micro.nix modules/home/cli/
mv shimboot_config/main_configuration/home/starship.nix modules/home/cli/
mv shimboot_config/main_configuration/home/fuzzel.nix modules/home/cli/
```

Create `modules/home/cli/default.nix`:

```nix
{ pkgs, ... }:
{
  imports = [
    ./fish.nix
    ./kitty.nix
    ./micro.nix
    ./starship.nix
    ./fuzzel.nix
  ];

  # Category-wide CLI utilities
  home.packages = with pkgs; [
    ripgrep
    fd
    eza
    jq
    tree
    # Add your CLI packages here
  ];
}
```

### 3.3 Move Desktop Modules

```bash
# Move desktop modules
mv shimboot_config/main_configuration/home/hyprland.nix modules/home/desktop/
mv shimboot_config/main_configuration/home/screenshot.nix modules/home/desktop/
mv shimboot_config/main_configuration/home/launcher.nix modules/home/desktop/
mv shimboot_config/main_configuration/home/audio-control.nix modules/home/desktop/
```

Create `modules/home/desktop/default.nix`:

```nix
{
  imports = [
    ./hyprland
    ./screenshot.nix
    ./launcher.nix
    ./audio-control.nix
  ];
}
```

### 3.4 Move Apps Modules

```bash
# Move app modules
mv shimboot_config/main_configuration/home/browser.nix modules/home/apps/
mv shimboot_config/main_configuration/home/editor.nix modules/home/apps/
mv shimboot_config/main_configuration/home/discord.nix modules/home/apps/
```

Create `modules/home/apps/default.nix`:

```nix
{
  imports = [
    ./browser.nix
    ./editor.nix
    ./discord.nix
  ];
}
```

### 3.5 Move Services Modules

```bash
# Move service modules
mv shimboot_config/main_configuration/home/syncthing.nix modules/home/services/
mv shimboot_config/main_configuration/home/ollama.nix modules/home/services/
mv shimboot_config/main_configuration/home/privacy.nix modules/home/services/
```

Create `modules/home/services/default.nix`:

```nix
{
  imports = [
    ./syncthing.nix
    ./ollama.nix
    ./privacy.nix
  ];
}
```

### 3.6 Move Core Modules

```bash
# Move core home modules
mv shimboot_config/main_configuration/home/stylix.nix modules/home/core/
mv shimboot_config/main_configuration/home/fonts.nix modules/home/core/
mv shimboot_config/main_configuration/home/environment.nix modules/home/core/
mv shimboot_config/main_configuration/home/xdg.nix modules/home/core/
```

Create `modules/home/core/default.nix`:

```nix
{
  imports = [
    ./stylix.nix
    ./fonts.nix
    ./environment.nix
    ./xdg.nix
  ];
}
```

### 3.7 Integrate Packages

For each module, ensure packages are co-located with config:

**Example - Before:**
```nix
# modules/home/cli/kitty.nix - Package elsewhere
{
  programs.kitty = { enable = true; };
}
```

**Example - After:**
```nix
# modules/home/cli/kitty.nix - Package integrated
{ pkgs, ... }:
{
  programs.kitty = { enable = true; };

  home.packages = [ pkgs.kitty ];
}
```

---

## Phase 4: Update Entry Points

### 4.1 Simplify `flake.nix`

**Current Pattern:** Complex with flake_modules helpers

**Target Pattern:** Explicit host configuration

```nix
# flake.nix - Simplified
{
  description = "Modular NixOS Flake - Shimboot";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Add your other inputs (stylix, hyprland, etc.)
    # stylix = { url = "github:danth/stylix"; inputs.nixpkgs.follows = "nixpkgs"; };
    # hyprland = { url = "github:hyprwm/Hyprland"; };
  };

  outputs =
    inputs@{ nixpkgs, home-manager, ... }:
    let
      vars = import ./vars;
      lib = import ./lib;
    in
    {
      # Optional: Add packages/formatter
      formatter = nixpkgs.lib.genAttrs [ vars.system ] (
        system: nixpkgs.legacyPackages.${system}.nixfmt-tree
      );

      nixosConfigurations = {
        shimboot0 = nixpkgs.lib.nixosSystem {
          inherit (vars.system);
          specialArgs = { inherit inputs vars hostName = "shimboot0"; };
          modules = [
            ./hosts/shimboot0/configuration.nix
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.extraSpecialArgs = { inherit inputs vars; hostName = "shimboot0"; };
              home-manager.users.${vars.username} = {
                imports = [ ./hosts/shimboot0/home.nix ];
              };
            }
            ./modules/nixos/core
            ./modules/nixos/desktop
            ./modules/nixos/hardware
            ./modules/nixos/services
            # Add hardware profile if needed
            ./modules/nixos/profiles/shimboot
          ];
        };

        # Add other hosts as needed
        # testboard0 = lib.mkHost "testboard0" [
        #   ./modules/nixos/core
        #   ./modules/nixos/profiles/testboard
        # ] { inherit inputs nixpkgs vars; };
      };
    };
}
```

### 4.2 Update Host Files

**`hosts/shimboot0/configuration.nix`** - Minimal:

```nix
{ pkgs, inputs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    # Add any device-specific inputs
  ];

  networking.hostName = "shimboot0";

  # Host-specific system packages
  environment.systemPackages = with pkgs; [
    # Add only host-specific packages
  ];
}
```

**`hosts/shimboot0/home.nix`** - Module bundles:

```nix
{ ... }:
{
  imports = [
    ../../modules/home/cli
    ../../modules/home/desktop
    ../../modules/home/apps
    ../../modules/home/services
    ../../modules/home/core
  ];

  # Host-specific files
  home.file.".config/hypr/monitors.conf".source = ./hypr_config/monitors.conf;
}
```

---

## Phase 5: Cleanup

### 5.1 Remove Old Directories

```bash
# After confirming all modules moved
rm -rf shimboot_config/base_configuration/
rm -rf shimboot_config/main_configuration/
rm -rf user-config.nix  # If vars/default.nix replaces it
```

### 5.2 Update `.gitignore`

```gitignore
# Ignore build result symlinks
result
result*

# Ignore backup files
*.bak
*.bak[0-9]
*.backup
*~

# Ignore temporary files
.DS_Store
Thumbs.db

# Ignore editor files
.vscode/
.idea/
.roo/
.swp
*.swo

# Ignore build artifacts
.opencode/
.kilocode/
node_modules/

# Ignore nix build artifacts
result-*
.direnv/

# Ignore test results
tools/test-results/
```

---

## Phase 6: Validation

### 6.1 Flake Check

```bash
cd ~/nixos-shimboot
nix flake check
```

### 6.2 Dry-Build All Hosts

```bash
# Dry-build each host
nix build .#nixosConfigurations.shimboot0.config.system.build.toplevel --dry-run
nix build .#nixosConfigurations.testboard0.config.system.build.toplevel --dry-run
```

### 6.3 Fix Issues

If errors occur, check:
1. Module paths in imports are correct
2. Packages are in `home.packages` or `environment.systemPackages`
3. Variables (`vars`, `hostName`) are in module arguments
4. Inputs are correctly defined in `flake.nix`

### 6.4 Format Code

```bash
nix fmt
```

---

## Phase 7: Finalize

### 7.1 Stage All Changes

```bash
git add -A
git status
```

### 7.2 Commit

```bash
git commit -m "Refactor: Convert to categorical-modular architecture

- Create vars/ and lib/ directories
- Move system modules to modules/nixos/{core,desktop,hardware,services,profiles}/
- Move home modules to modules/home/{cli,desktop,apps,services,core}/
- Integrate packages into respective modules
- Create hardware profiles for device-specific configs
- Simplify flake.nix to show explicit host configuration
- Replace user-config.nix with vars/default.nix
- Update nixpkgs to nixos-unstable
- Replace function-based config with plain attribute set
- Remove old shimboot_config/ directories
- Update .gitignore to exclude build artifacts
- All hosts pass nix flake check and dry-run tests"
```

### 7.3 Push

```bash
git push origin refactor-modular
```

### 7.4 Merge & Cleanup

```bash
# Merge to main branch
git checkout main
git merge refactor-modular

# Push merged changes
git push origin main

# Delete refactor branch
git branch -d refactor-modular
git push origin --delete refactor-modular
```

---

## Common Patterns

### Module Signature Pattern

```nix
# Standard module signature
{ inputs, pkgs, vars, hostName, ... }:
{
  # Module content here
}
```

### Bundle Pattern

```nix
# Category bundle (default.nix)
{ pkgs, ... }:
{
  imports = [
    ./module1.nix
    ./module2.nix
    ./module3.nix
  ];

  # Category-wide packages
  home.packages = with pkgs; [
    package1
    package2
  ];
}
```

### Host Pattern

```nix
# Host system configuration
{ pkgs, inputs, ... }:
{
  imports = [
    ./hardware-configuration.nix
  ];

  networking.hostName = "your-hostname";

  # Host-specific system packages
  environment.systemPackages = with pkgs; [
    # Add only host-specific packages
  ];
}
```

### Home Config Pattern

```nix
# Host home configuration
{ ... }:
{
  imports = [
    # Import category bundles
    ../../modules/home/cli
    ../../modules/home/desktop
    ../../modules/home/apps
    ../../modules/home/services
    ../../modules/home/core
  ];

  # Host-specific files
  home.file.".config/app/config.conf".source = ./config/file.conf;
}
```

---

## Troubleshooting Guide

### Error: "Variable undefined: vars"

**Cause:** `vars` not in module arguments

**Fix:** Add to function signature:
```nix
{ vars, pkgs, inputs, ... }:
{
  # Module content
}
```

### Error: "Package not found"

**Cause:** Package reference is incorrect

**Fix:** Check one of:
1. Package exists in nixpkgs: `pkgs.mypackage`
2. Package from input: `inputs.myinput.packages.${pkgs.system}.default`
3. Package path is correct

### Error: "Module not found"

**Cause:** Path in imports is incorrect

**Fix:** Ensure path is relative to module location:
```nix
# In modules/home/core/default.nix
imports = [
  ./stylix.nix  # Correct: same directory
  ../../modules/home/cli/fish.nix  # Incorrect: wrong path
];
```

---

## Design Principles Applied

### KISS (Keep It Simple, Stupid)

✅ **Folder imports** - Import categories instead of 10+ files
✅ **Plain attribute sets** - No function wrapping
✅ **Explicit hosts** - See host config at a glance in flake.nix

### DRY (Don't Repeat Yourself)

✅ **Hardware profiles** - Reusable device configs
✅ **Centralized variables** - Single source of truth in `vars/`
✅ **Helper functions** - Reusable logic in `lib/`

### Locality

✅ **Packages with config** - Each module owns its dependencies
✅ **Related files grouped** - Desktop files together, etc.

### Scalability

✅ **Pick-and-choose** - Add hosts with minimal changes
✅ **Clear separation** - Easy to find where to add features
✅ **Discoverable** - Categorized by domain (CLI, Desktop, Apps, etc.)

---

## Comparison: Before vs After

### Finding Configuration

| Task | Before | After | Improvement |
|-------|--------|-------|-------------|
| Find Fish config | Search 30+ files | Check `modules/home/cli/fish.nix` | **96% reduction** |
| Find terminal config | Search 30+ files | Check `modules/home/cli/kitty.nix` | **96% reduction** |
| Find browser config | Search package lists | Check `modules/home/apps/browser.nix` | **Eliminates confusion** |

### Adding New Features

| Task | Before | After | Improvement |
|-------|--------|-------|-------------|
| Add new CLI tool | Edit packages, add to user-config | Create module, add to bundle | **Significantly reduced** |
| Add new host | Edit multiple files | Add one entry to flake.nix | **80% reduction** |
| Delete app | Remove from packages, remove from home | Delete module file | **Auto-removes package** |

### Reusability

| Task | Before | After |
|-------|--------|-------|
| Share config between hosts | Copy entire files | Import same profile | **Now possible** |
| Hardware rules for similar devices | Repeat in each host | Import reusable profile | **DRY achieved** |

---

## Project-Specific Notes

### Shimboot-Specific Considerations

**Bootloader Integration:**
- You have `bootloader/` directory with custom scripts
- Consider creating `modules/nixos/profiles/shimboot/boot.nix`
- Integrate with existing `assemble-final.sh`

**Cross-System Integration:**
- You have `flake_modules/crossystem/` for cross-compilation
- Keep as-is or create `modules/nixos/core/crossystem.nix`
- Import in host configs that need cross-compilation

**Image Building:**
- You have `raw-image.nix` and related modules
- Keep these as top-level or move to `modules/nixos/build/`
- Consider if they need refactoring (likely not if already modular)

**Test Board Integration:**
- You have test-related manifests and tools
- Test board configs could be `modules/nixos/profiles/testboard/`
- Consider creating separate test host configuration

**LLM Development:**
- You have `llm-notes/` directory
- Create `modules/home/ai/` if you have LLM-related home modules
- Keep documentation as-is or add to `docs/`

### Shimboot-Specific Module Mapping

If your shimboot_config has these modules, map them as follows:

| Category | Modules to Map |
|----------|----------------|
| Core | environment, boot, networking, localization, users, fish, packages, programs |
| Desktop | display, fonts, greeter, display-manager, hyprland, theme |
| Hardware | hardware, audio, bluetooth, tablet, power-management |
| Services | ssh, syncthing, virtualization, vpn |

---

## Resource Links

### Documentation

- [NixOS Manual](https://nixos.org/manual)
- [NixOS Wiki](https://nixos.wiki)
- [Home Manager Manual](https://nix-community.github.io/home-manager/)

### Community

- [NixOS Discourse](https://discourse.nixos.org)
- [r/NixOS](https://reddit.com/r/NixOS)
- [NixOS Matrix](https://matrix.to/#/#nix:nixos.org)

### Inspiration

- [nix-community/nixos-configurations](https://github.com/nix-community/nixos-configurations)
- Search GitHub for "NixOS flake" examples
- The refactored nixos-config structure as reference

---

## Success Metrics

Track before/after improvements:

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| Files to scan for config | 60+ | Categorized folders | **Organized** |
| Package location confusion | High | None | **Eliminated** |
| Add new host complexity | High | Low | **Reduced** |
| Reusable configuration | None | Yes | **Now possible** |

---

## Final Notes

This guide provides a **project-specific refactoring roadmap** for converting the nixos-shimboot flat-file architecture to a modular structure.

### Key Advantages Achieved

- ✅ Clear categorization by domain (CLI, Desktop, Apps, Services, Core, Hardware)
- ✅ Minimal host configuration in `flake.nix`
- ✅ Package locality with configuration
- ✅ Hardware profiles for device reusability
- ✅ Elimination of Nix-debt (minimal changes for new features)

### Nix-Debt Eliminated

Adding features now requires:
- ✅ Creating one module file
- ✅ Adding to one bundle's imports
- ✅ Editing minimal files (host entry in flake.nix)

### Modular Architecture Benefits

- **Discoverability:** Find Fish config in `modules/home/cli/fish.nix`
- **Scalability:** Add new hosts by copying host file and updating imports
- **Maintainability:** Changes to a module affect all hosts using it
- **Portability:** Share profiles between hosts and projects

---

**End of Shimboot Refactoring Guide**

*Last Updated: 2026-01-17*
*Based on: Modular refactoring methodology from nixos-config*
