# NixOS Module Scaffold

## Header Template

```nix
# <Module Name>
#
# Purpose: <Brief description of its function>
# Dependencies: <pkg1, pkg2, ...> | None
# Related: <file1.nix, file2.nix> | None
#
# This module:
# - <What it enables/configures>
# - <Dependency or related feature>
# - <Additional internal notes>
```

## System Module Scaffold

```nix
# <Module Name>
#
# Purpose: <description>
# Dependencies: <packages> | None
# Related: <files> | None
#
# This module:
# - <bullet points>
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

## Home Module Scaffold

```nix
# <Module Name>
#
# Purpose: <description>
# Dependencies: <packages> | None
# Related: <files> | None
#
# This module:
# - <bullet points>
{
  config,
  lib,
  pkgs,
  ...
}: let
  # Local bindings
in {
  home.packages = with pkgs; [
    # packages
  ];

  # programs/services configuration
}
```

## Section Markup

| Level | Format | Example |
|-------|--------|---------|
| L1 | `# TITLE` + `=` underbar | `# AUDIO MODULE` followed by `# ====` |
| L2 | `## Section` + `-` underbar | `## PipeWire` followed by `# ----` |
| L3 | `### Subpoint` | `### Notes` |

## Required Fields

- Purpose: One-liner describing function (required)
- Dependencies: Package names or "None" (required)
- Related: Related module files or "None" (optional)
- This module: Bullet list of behaviors (required)

## Style Rules

- Indentation: 2 spaces
- Line width: 100 characters max
- Trailing newline: single at EOF
- Tone: Declarative, present tense ("Enables", "Configures")
- No first-person ("I", "we")

## Validation

Before commit:
```bash
nix flake check --impure --accept-flake-config
