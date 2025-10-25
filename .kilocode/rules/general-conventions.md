# LLM Workspace Rule: General Conventions

## Module Commenting

### Header Format
```nix
# <Module Name>
#
# Purpose: <Single-line intent>
# Dependencies: <pkg1, pkg2, ...> | None
# Related: <file1.nix, file2.nix> | None
#
# This module:
# - <Key responsibility 1>
# - <Key responsibility 2>
# - <Key responsibility 3>
```

### Examples

**System Module:**
```nix
# Networking Configuration Module
#
# Purpose: Configure network services for ChromeOS compatibility
# Dependencies: networkmanager, wpa_supplicant
# Related: hardware.nix, services.nix
#
# This module:
# - Enables NetworkManager with wpa_supplicant backend
# - Configures firewall with SSH access
# - Loads WiFi kernel modules for ChromeOS devices
# - Handles rfkill unblocking for WLAN
{
  config,
  pkgs,
  lib,
  ...
}: {
  # implementation
}
```

**Home Module:**
```nix
# Kitty Terminal Module
#
# Purpose: Configure Kitty terminal emulator with Rose Pine theme
# Dependencies: None
# Related: theme.nix
#
# This module:
# - Enables Kitty with Fish shell integration
# - Configures Rose Pine color scheme
# - Sets up terminal behavior and appearance
{pkgs, ...}: {
  # implementation
}
```

**Helper Script:**
```bash
#!/usr/bin/env bash

# Harvest Drivers Script
#
# Purpose: Extract ChromeOS kernel modules, firmware, and modprobe configs from SHIM and RECOVERY images
# Dependencies: losetup, mount, umount, cp, find, xargs, sudo
# Related: fetch-recovery.sh, fetch-manifest.sh
#
# This script mounts ChromeOS images read-only, extracts kernel modules and firmware,
# and merges modprobe configurations for use in NixOS shimboot.
#
# Usage:
#   sudo ./tools/harvest-drivers.sh --shim shim.bin --recovery recovery.bin --out drivers/

set -euo pipefail
```

### Rules

**Purpose Field:**
```
- Single line only
- State what, not how
- No implementation details
- End with period

Good: "Configure system fonts for optimal display and compatibility"
Bad:  "Install Noto fonts and configure fontconfig defaultFonts"
```

**Dependencies Field:**
```
- List direct dependencies only (not transitive)
- Use package names, not derivation paths
- Use "None" if no external dependencies
- Comma-separated, no "and"

Good: "hyprland, lightdm, xdg-desktop-portal"
Bad:  "hyprland and lightdm"
```

**Related Field:**
```
- List files that are commonly edited together
- Use relative paths from same directory
- Maximum 3-4 files
- Use "None" if standalone module

Good: "hardware.nix, display.nix"
Bad:  "../system_modules/hardware.nix"
```

**"This module" Section:**
```
- Use bullet list format
- Start each with verb (present tense)
- Maximum 5 bullets
- Order: most important first
- One concern per bullet

Good:
# - Enables Hyprland with XWayland support
# - Configures LightDM display manager
# - Sets up XDG portals for Wayland compatibility

Bad:
# - This module sets up Hyprland and also configures
#   LightDM and handles the XDG portal configuration
```

### When to Update Headers

```
Module renamed:
└─ Update: Module Name line

New dependency added:
└─ Update: Dependencies field

Related files changed:
└─ Update: Related field

Key functionality added/removed:
└─ Update: "This module" section

Purpose unclear:
└─ Rewrite: Purpose field (single-line clarity test)
```

---

## Commit Conventions

### Format
```
<type>(file01,...): <action> <summary>

[optional body]
```

### Type Categories
```
feat     - New feature or capability
fix      - Bug fix
refactor - Code restructure without behavior change
docs     - Documentation only
style    - Formatting, whitespace (no logic change)
test     - Add/modify tests
chore    - Maintenance tasks (deps, tools)
perf     - Performance improvement
revert   - Revert previous commit
```

### Scope (file list)
```
Rules:
├─ List changed files (max 3)
├─ Use basename only (no path)
├─ Comma-separated, no spaces
├─ If >3 files, use directory name
└─ Omit extension if obvious from context

Examples:
(flake.nix)
(networking,hardware)
(base_configuration)
(home_modules/theme)
```

### Action Verbs
```
add       - New content
remove    - Delete content
update    - Modify existing content
fix       - Correct broken behavior
refactor  - Restructure without functional change
implement - Complete partial implementation
enable    - Activate feature
disable   - Deactivate feature
configure - Set up options
integrate - Connect components
```

### Summary
```
Rules:
├─ Imperative mood ("add" not "adds" or "added")
├─ Lowercase first word
├─ No period at end
├─ Max 72 characters total (type + scope + summary)
└─ State what changes, not why

Good: "add zram swap configuration"
Bad:  "Added ZRAM support because it improves performance."
```

### Examples

**Single File:**
```
feat(zram.nix): add zram swap configuration

- Enable zram with lzo compression
- Configure memoryPercent to 100
- Load kernel module automatically
```

**Multiple Files (≤3):**
```
refactor(helpers): split filesystem and setup helpers

- Extract setup_nixos to setup-helpers.nix
- Extract expand_rootfs to filesystem-helpers.nix
- Update helpers.nix imports
```

**Directory Scope:**
```
feat(home_modules): add wezterm terminal configuration

- Configure Rose Pine theme
- Set up font and cursor settings
- Add to packages list
```

**Fix:**
```
fix(assemble-final.sh): correct vendor partition bind order

Vendor drivers were being bound after pivot_root, causing
module loading failures. Now bind before pivot_root to
ensure modules available at systemd start.
```

**Chore:**
```
chore(flake): update nixpkgs input to latest unstable
```

**Docs:**
```
docs(SPEC): update section 5 with new module structure

- Add squashfs-helpers subsection
- Update module tree with zram.nix
- Clarify vendor driver integration
```

**Refactor:**
```
refactor(base_configuration): consolidate helper modules

- Create helpers/ subdirectory
- Move filesystem, permissions, setup helpers
- Update configuration.nix imports
```

### Body Guidelines

```
Include body when:
├─ Change requires explanation (why, not what)
├─ Breaking change
├─ Multiple related changes
└─ Non-obvious side effects

Format:
├─ Wrap at 72 characters
├─ Separate from summary with blank line
├─ Use bullet points for multiple items
└─ Reference issues with #123 syntax
```

### Examples with Body

**Breaking Change:**
```
feat(bootstrap.sh): add multi-rootfs partition detection

BREAKING: Changes partition detection logic. Existing
shimboot images must be rebuilt to use new bootloader.

- Scan for shimboot_rootfs:* pattern
- Display menu for multiple partitions
- Maintain backward compatibility with single rootfs
```

**Complex Fix:**
```
fix(harvest-drivers.sh): prevent firmware symlink breakage

ChromeOS firmware contains symlinks to /opt/* paths which
break when copied. Now uses cp -L to dereference symlinks
during harvest, ensuring firmware files are real copies.

- Add -L flag to cp commands
- Test on dedede board firmware
- Verify iwlwifi firmware loads correctly
```

**Multiple Related Changes:**
```
refactor(flake_modules): reorganize chromeos derivations

- Extract kernel-extraction.nix from monolithic file
- Extract initramfs-extraction.nix
- Extract initramfs-patching.nix
- Update flake.nix imports

Improves maintainability and isolates build stages.
```

### Anti-Patterns

**Avoid:**
```
Bad type:
└─ "update(file): updates things"
   (redundant verb in summary)

Bad scope:
└─ "feat(shimboot_config/base_configuration/system_modules/networking.nix): ..."
   (full path instead of basename)

Bad action:
└─ "fix(networking): networking now works"
   (vague, no actionable info)

Bad summary:
└─ "feat: stuff"
   (no scope, no specifics)

Bad summary:
└─ "feat(flake): Added support for new boards, updated dependencies, and fixed some bugs."
   (multiple unrelated changes in one commit)
```

**Good:**
```
feat(flake): add octopus board support
chore(flake): update nixpkgs to latest unstable
fix(networking): resolve WiFi radio blocking on dedede
```

### Scope Edge Cases

**No specific file:**
```
chore: update .gitignore patterns
docs: add QUICKSTART.md
test: add board build verification script
```

**Generated files:**
```
chore(manifests): regenerate dedede manifest

Ran tools/fetch-manifest.sh to update chunk hashes.
```

**Script and config:**
```
feat(assemble-final,flake): add squashfs compression support

- Add --compress-store flag to assemble-final.sh
- Add squashfs-tools to nix build inputs
- Update flake.nix to pass compression option
```

### Commit Frequency

```
Commit when:
├─ Single logical change complete
├─ Tests pass (if applicable)
├─ Feature milestone reached
└─ Before switching context

Avoid:
├─ "WIP" commits (use git stash instead)
├─ Mixing unrelated changes
└─ Committing broken state
```

### Tools Integration

**Git Alias:**
```bash
[alias]
  c = "!f() { \
    local type=\"$1\" scope=\"$2\" action=\"$3\"; shift 3; \
    git commit -m \"$type($scope): $action $*\"; \
  }; f"
  
# Usage: git c feat zram.nix add zram swap configuration
```

**Pre-commit Hook:**
```bash
#!/bin/bash
# .git/hooks/commit-msg

commit_msg=$(cat "$1")
pattern='^(feat|fix|docs|style|refactor|test|chore|perf|revert)\([^)]+\): [a-z].+[^.]$'

if ! echo "$commit_msg" | head -1 | grep -Eq "$pattern"; then
  echo "Error: Commit message doesn't follow convention"
  echo "Format: <type>(scope): <action> <summary>"
  exit 1
fi
```

---

# LLM Workspace Rule: Git Tracking & Flake Validation

## Git Tracking Rules

### Always Track
```
Source files:
├─ *.nix files (all configurations and derivations)
├─ *.sh scripts (tools/, assemble-final.sh)
├─ *.fish functions (fish_functions/)
├─ *.conf configs (hypr/, monitors.conf, userprefs.conf)
├─ Documentation (*.md, SPEC.md)
└─ License files (LICENSE)

Generated but versioned:
├─ manifests/*-manifest.nix (generated by fetch-manifest.sh)
└─ flake.lock (Nix dependency lock file)
```

### Never Track
```
Build artifacts:
├─ work/ (entire directory)
├─ result* symlinks (Nix build outputs)
├─ *.img, *.bin, *.zip (disk images, binaries)
├─ .temp/, .backup/ (temporary build directories)
└─ harvested/ (ChromeOS driver extraction cache)

Nix garbage:
├─ .direnv/ (if using direnv)
├─ .pre-commit-config.yaml.backup
└─ gcroots/ (if used locally)

Editor/IDE:
├─ .vscode/, .idea/
├─ *.swp, *.swo, *~
└─ .DS_Store (macOS)

User-specific:
├─ .envrc.local
└─ local-config.nix (if implemented)
```

### Check Before Committing
```bash
# Verify .gitignore is working
git status --ignored

# Should show:
#   work/
#   result
#   result-*
#   *.img
#   .temp/
```

### Adding New Files Checklist
```
New .nix module:
├─ [ ] Add module comment header
├─ [ ] Import in parent configuration
├─ [ ] Run nix flake check (see below)
├─ [ ] git add <file>
└─ [ ] Commit with feat(file): add <summary>

New .sh script:
├─ [ ] Add script comment header
├─ [ ] Make executable: chmod +x
├─ [ ] Add to tools/ or root as appropriate
├─ [ ] git add <file>
└─ [ ] Commit with feat(file): add <summary>

New documentation:
├─ [ ] Verify markdown formatting
├─ [ ] Update README.md links if needed
├─ [ ] git add <file>
└─ [ ] Commit with docs(file): add <summary>
```

---

## Flake Check Workflow

### When to Run
```
Required before commit:
├─ Modified flake.nix
├─ Modified any flake_modules/*.nix
├─ Modified base_configuration/*.nix
├─ Modified main_configuration/*.nix
└─ Added/removed NixOS modules

Optional but recommended:
├─ Modified tools/ scripts (may affect derivations)
├─ Modified manifests/*.nix
└─ Before pushing to remote
```

### Basic Check
```bash
# Quick syntax and evaluation check
nix flake check --impure --accept-flake-config

# Expected output (success):
# checking flake output 'nixosConfigurations'...
# checking flake output 'packages'...
# evaluating derivation 'nixosConfigurations.${hostname}'
# evaluating derivation 'packages.x86_64-linux.raw-rootfs'
# ...
```

### Check Variants
```bash
# Full check (may take time, downloads dependencies)
nix flake check

# Check specific output
nix flake check --impure .#nixosConfigurations.${hostname}

# Show what would be checked without building
nix flake show
```

### Common Failures

**Syntax Error:**
```
error: syntax error, unexpected IN, expecting '}'
at /path/to/file.nix:42:5
```
Action: Fix syntax at indicated line

**Import Error:**
```
error: file 'some-module.nix' was not found in the Nix search path
```
Action: Verify imports = [ ./path/to/module.nix ];

**Infinite Recursion:**
```
error: infinite recursion encountered
```
Action: Check for circular imports or self-referencing values

**Type Error:**
```
error: value is a set while a string was expected
```
Action: Verify option types match declarations

**Missing Input:**
```
error: flake input 'some-input' does not exist
```
Action: Add input to flake.nix or update flake.lock

### Handling Check Failures

**Workflow:**
```
1. Run: nix flake check --impure --accept-flake-config
2. Read error message carefully
3. Identify failing file and line number
4. Fix issue
5. Re-run check
6. Repeat until clean

Do not commit if checks fail (unless explicitly documenting breakage)
```

**Temporary Check Skip (use sparingly):**
```bash
# If check takes too long and change is isolated
git commit -m "feat(file): add feature [skip-check]"

# Only use when:
# - Change does not affect flake structure
# - Tested manually
# - Will run check in CI/later
```

### Integration with Commit Flow

**Standard Workflow:**
```bash
# 1. Make changes
vim shimboot_config/base_configuration/system_modules/new-module.nix

# 2. Check syntax and evaluation
nix flake check --impure --accept-flake-config

# 3. If success, stage and commit
git add shimboot_config/base_configuration/system_modules/new-module.nix
git commit -m "feat(new-module): add new system configuration"

# 4. If failure, fix and repeat from step 2
```

**Quick Validation Alias:**
```bash
# Add to ~/.bashrc or ~/.config/fish/config.fish
alias fcheck='nix flake check --impure --accept-flake-config'

# Usage:
fcheck && git commit -m "feat(file): message"
```

### Special Cases

**Large Derivation Changes:**
```bash
# Check syntax without building
nix flake check --no-build --impure --accept-flake-config

# If syntax OK but want to skip full build check:
git commit -m "refactor(flake): restructure derivations [skip-build-check]"
```

**Manifest Regeneration:**
```bash
# After running fetch-manifest.sh
git diff manifests/dedede-manifest.nix  # Verify changes are expected
nix flake check --impure  # Verify manifest is valid
git add manifests/dedede-manifest.nix
git commit -m "chore(manifests): regenerate dedede manifest"
```

**Flake Lock Updates:**
```bash
# After nix flake update
git diff flake.lock  # Review input changes
nix flake check --impure  # Verify compatibility
git add flake.lock
git commit -m "chore(flake): update nixpkgs input to latest unstable"
```

### Pre-Push Validation

```bash
# Before pushing to remote
nix flake check --impure --accept-flake-config
nix flake show  # Verify expected outputs exist

# Optional: Test build key derivations
nix build .#raw-rootfs --dry-run
nix build .#chromeos-shim-dedede --dry-run
```

### CI/CD Integration Note

```
If CI runs flake check:
├─ Local check ensures push won't fail CI
├─ Use same flags as CI for consistency
└─ Document CI check command in README.md or .github/workflows/

If no CI:
├─ Local check is the only validation
└─ More critical to check before every commit
```

---

## .gitignore Template

```gitignore
# Build artifacts
work/
result
result-*
*.img
*.bin
*.zip
.temp/
.backup/
harvested/

# Nix
.direnv/
.pre-commit-config.yaml.backup
gcroots/

# Editor
.vscode/
.idea/
*.swp
*.swo
*~
.DS_Store

# User-specific
.envrc.local
local-config.nix
```

---

## Quick Reference

**Pre-Commit Checklist:**
```
[ ] Files staged: git status
[ ] No build artifacts staged: git status --ignored
[ ] Flake check passed: nix flake check --impure --accept-flake-config
[ ] Commit message follows convention: <type>(scope): <action> <summary>
[ ] Module header present (if new .nix file)
```

**Common Commands:**
```bash
# Check what's tracked
git ls-files

# Check what's ignored
git status --ignored

# Validate flake
nix flake check --impure --accept-flake-config

# Show flake outputs
nix flake show

# Test build without building
nix build .#raw-rootfs --dry-run
```

**Emergency Unstage:**
```bash
# Unstage accidentally added file
git reset HEAD work/shimboot.img

# Add to .gitignore if needed
echo "work/" >> .gitignore
git add .gitignore
```