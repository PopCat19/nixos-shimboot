# Module Structure

## Header Template

```nix
# <Module Name>
#
# Purpose: <Intent-focused outcome>
# Rationale: <Strategic reasoning for this config>
# Related: <file1.nix, file2.nix> | None
#
# Note: External constraints (e.g., "Requires 10GB disk space")
{
  config,
  pkgs,
  lib,
  ...
}: {
  # implementation
}
```

## Field Guidelines

**Purpose Field**
- Describe the business/system value (outcome)
- One line maximum

Good → `Configure system fonts for optimal display.`
Bad → `Installs Noto fonts and sets defaults.`

**Rationale Field**
- Explain "Why," especially for magic values or hacks
- Mention hardware-specific requirements
- Document non-obvious decisions

**Related Field**
- List files frequently edited together
- Use relative names from the same directory
- Max 3 to 4 entries
- Write "None" when not applicable

Good → `hardware.nix, display.nix`
Bad → `../system_modules/hardware.nix`

**Note Section**
- External constraints (disk space, memory, etc.)
- Known limitations or workarounds
- Important prerequisites

## Module Types

### System Module
```nix
# <Module Name>
#
# Purpose: <Functional intent>
# Rationale: <Why this config is necessary>
# Related: <files> | None
#
# Note: <External constraints>
{
  config,
  lib,
  pkgs,
  ...
}: let
  # Local bindings
in {
  # Configuration
}
```

### Home Module
```nix
# <Module Name>
#
# Purpose: <description>
# Rationale: <reasoning>
# Related: <files> | None
{
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    # packages
  ];

  # programs/services configuration
}
```

### Helper Script
```bash
#!/usr/bin/env bash

# <Script Name>
#
# Purpose: <Brief description>
# Rationale: <Why needed>
# Related: <related files>
#
# Note: <Important notes>
set -euo pipefail
```

## Example Headers

**System Module**
```nix
# Networking Configuration Module
#
# Purpose: Configure network stack for ChromeOS integration.
# Rationale: Requires WiFi kernel modules for Chromebook hardware.
# Related: hardware.nix, services.nix
#
# Note: Requires networkmanager and wpa_supplicant
```

**Home Module**
```nix
# Kitty Terminal Module
#
# Purpose: Configure Kitty terminal with Rose Pine theme.
# Rationale: Rose Pine provides consistent visual identity.
# Related: theme.nix
```

**Helper Script**
```bash
# Harvest Drivers Script
#
# Purpose: Extract ChromeOS kernel modules and firmware.
# Rationale: NixOS shimboot requires proprietary ChromeOS drivers.
# Related: fetch-recovery.sh, fetch-manifest.sh
#
# Note: Mounts ChromeOS images read-only
```

## Style Rules

- Indentation: 2 spaces
- Line width: 100 characters max
- Trailing newline: single at EOF
- Tone: Declarative, present tense ("Enables", "Configures")
- No first-person ("I", "we")

## Validation

```bash
nix flake check --impure --accept-flake-config
```
