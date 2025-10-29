# LLM Workspace Rule: General Conventions

## 1. Module Commenting

### 1.1 Header Template
```nix
# <Module Name>
#
# Purpose: <Single-line function or intent>
# Dependencies: <pkg1, pkg2, ...> | None
# Related: <file1.nix, file2.nix> | None
#
# This module:
# - <Key responsibility 1>
# - <Key responsibility 2>
# - <Key responsibility 3>
{
  config,
  pkgs,
  lib,
  ...
}: {
  # implementation
}
```

### 1.2 Header Content Rules
**Purpose Field**
- One line only.
- Describe functional intent (what, not how).
- End with period.

Good → `Configure system fonts for optimal display.`
Bad → `Installs Noto fonts and sets defaults.`

**Dependencies Field**
- Only direct dependencies.
- Use comma-separated package names.
- Write “None” when not applicable.

Good → `networkmanager, wpa_supplicant`
Bad → `networkmanager and wpa_supplicant`

**Related Field**
- List files frequently edited together.
- Use relative names from the same directory.
- Max 3 to 4 entries.

Good → `hardware.nix, display.nix`
Bad → `../system_modules/hardware.nix`

**“This module” Section**
- Bullet points only.
- Begin each with a verb.
- Limit to 5 items (important first).
- Describe distinct responsibilities.

### 1.3 Example Headers

**System Module**
```nix
# Networking Configuration Module
#
# Purpose: Configure network stack for ChromeOS integration.
# Dependencies: networkmanager, wpa_supplicant
# Related: hardware.nix, services.nix
#
# This module:
# - Enables NetworkManager
# - Configures firewall access
# - Loads WiFi kernel modules
{
  ...
}
```

**Home Module**
```nix
# Kitty Terminal Module
#
# Purpose: Configure Kitty terminal with Rose Pine theme.
# Dependencies: None
# Related: theme.nix
#
# This module:
# - Enables Kitty with Fish shell
# - Applies Rose Pine color theme
# - Sets up terminal behavior
{pkgs, ...}: {
  ...
}
```

**Helper Script**
```bash
#!/usr/bin/env bash

# Harvest Drivers Script
#
# Purpose: Extract ChromeOS kernel modules and firmware.
# Dependencies: losetup, mount, umount, cp, find, xargs, sudo
# Related: fetch-recovery.sh, fetch-manifest.sh
#
# Mounts ChromeOS images read-only and extracts drivers for NixOS shimboot.

set -euo pipefail
```

**Header Maintenance**
- Update module name on rename.
- Add new dependency when present.
- Update related field when new related files appear.
- Update bullet list when adding/removing module functions.

---

## 2. Commit Conventions

### 2.1 Format
```
<type>(scope): <action> <summary>
```

### 2.2 Types
| Type | Meaning |
|------|----------|
| feat | New feature or capability |
| fix | Bug correction |
| refactor | Code structure change without functional change |
| docs | Documentation or comments only |
| style | Whitespace or formatting only |
| test | Tests addition or modification |
| chore | Maintenance or dependency updates |
| perf | Performance improvement |
| revert | Undo previous commit |

### 2.3 Scope Rules
- Scope = file or folder name (`basename` only).
- Up to 3 comma-separated scopes.
- Use directory name for large changes.
- Lowercase only.
- Omit extensions unless ambiguous.

Good → `(flake.nix)`  
Good → `(networking,hardware)`  
Bad → `(shimboot_config/base_configuration/networking.nix)`

### 2.4 Action Verbs
| Verb | Use |
|------|-----|
| add | Introduce new content |
| remove | Delete file or behavior |
| update | Modify existing content |
| fix | Correct defective logic |
| refactor | Rearrange code structure |
| implement | Complete or finalize feature |
| enable | Activate behavior |
| disable | Deactivate behavior |
| configure | Set up configuration |
| integrate | Combine components |

### 2.5 Summary
Rules:
- Imperative mood ("add", not "added").
- Lowercase first word.
- No ending punctuation.
- Max 72 characters.
- Describe *what*, not *why*.

Good → `add zram swap configuration`  
Bad → `Added ZRAM support for better performance.`

---

## 3. Examples

**Single File**
```
feat(zram.nix): add zram swap configuration

- Enable zram
- Configure memoryPercent to 100
- Load kernel module
```

**Multiple Files**
```
refactor(helpers): split filesystem and setup helpers

- Move expand_rootfs
- Create setup-helpers.nix
- Update helper imports
```

**Directory Scope**
```
feat(home_modules): add wezterm terminal configuration

- Configure Rose Pine theme
- Add font settings
```

**Fix**
```
fix(assemble-final.sh): correct vendor bind order

Drivers were bound after pivot_root, causing failures.
Now bound before systemd start.
```

**Chore**
```
chore(flake): update nixpkgs input to unstable
```

**Docs**
```
docs(SPEC): update section 5 module structure
```

**Refactor**
```
refactor(base_configuration): consolidate helper modules
```

---

## 4. Body Guidelines

Add body when:
- The reasoning is non-obvious.
- There is a breaking change.
- The commit encompasses multiple sub-edits.
- There are notable side effects.

Formatting:
- Wrap each line at 72 chars.
- One blank line between header and body.
- Use list bullets for multiple points.

Example:
```
fix(harvest-drivers.sh): dereference symlinks during extraction

ChromeOS firmware contains symlinks to /opt paths breaking copy.
Now uses cp -L for valid firmware deployment.

- Added -L flag to cp
- Verified on dedede firmware
```

---

## 5. Validation

**Regex**
```bash
^(feat|fix|docs|style|refactor|test|chore|perf|revert)\([^)]+\): [a-z].+[^.]$
```

**Pre-Commit Hook**
```bash
#!/bin/bash
msg=$(cat "$1")
pattern='^(feat|fix|docs|style|refactor|test|chore|perf|revert)\([^)]+\): [a-z].+[^.]$'

if ! grep -Eq "$pattern" "$1"; then
  echo "❌ Invalid commit message."
  echo "Use: <type>(scope): <action> <summary>"
  exit 1
fi
```

---

## 6. Workflow Practice

**Commit When**
- Single logical change complete.
- Tests or `flake check` pass.
- Feature milestone achieved.
- Before switching task context.

**Avoid**
- “WIP” or temporary commits.
- Mixed unrelated edits.
- Broken or untested changes.

---

## 7. Git Tracking Policy

**Always Track**
```
*.nix, *.sh, *.fish, *.conf, *.md, LICENSE
manifests/*-manifest.nix
flake.lock
```

**Never Track**
```
work/, result*, *.img, *.bin, *.zip, .temp/
harvested/, .direnv/, gcroots/
.vscode/, .idea/, *.swp, *~, .DS_Store
.envrc.local, local-config.nix
```

---

## 8. Flake Validation Workflow

**Run Before Commit**
```
nix flake check --impure --accept-flake-config
```

**Typical Output**
```
checking flake output 'nixosConfigurations'...
checking flake output 'packages'...
evaluation successful.
```

**Use shortcut**
```bash
alias fcheck='nix flake check --impure --accept-flake-config'
```

**Optional Quick Checks**
```
nix flake show
nix build .#raw-rootfs --dry-run
```

**If error**
1. Read trace line and fix syntax or import.
2. Re-run until clean.
3. Never commit failing check unless flagged `[skip-check]`.

---

## 9. Quick Commit Examples

| Type | Example |
|------|----------|
| feat | `feat(flake): add new board support` |
| fix | `fix(networking): repair wlan rfkill blocking` |
| docs | `docs(CONVENTIONS): clarify header format rules` |
| refactor | `refactor(helpers): reorganize filesystem utils` |
| chore | `chore(flake): bump nixpkgs unstable` |

---

## 10. Summary Checklist

✅ Header block at top of each module  
✅ Purpose concise, declarative  
✅ Flake validated via `nix flake check`  
✅ Commit message formatted correctly  
✅ No generated artifact committed  
✅ Pre-commit regex passes  

> Follow these standards for all modules, scripts, and commits in the NixOS Shimboot repository to ensure readability, traceability, and reproducibility.