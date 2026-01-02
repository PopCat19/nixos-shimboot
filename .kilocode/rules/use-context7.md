# Use Context7 for Documentation

Use Context7 MCP server for up-to-date library and framework documentation lookups.

## Purpose

Context7 provides current, version-specific documentation directly in the workflow,
eliminating outdated information and reducing hallucination in code generation.

## When to Use

- Looking up API signatures for unfamiliar packages
- Checking NixOS option syntax and available attributes
- Verifying Home Manager module options
- Understanding library function parameters
- Confirming package configuration patterns

## Usage Pattern

### Before Writing Module Code
1. Query Context7 for relevant documentation
2. Verify option names and types
3. Check for deprecated or renamed options
4. Confirm package attribute paths

### Example Queries
- NixOS networking options
- Home Manager programs.fish configuration
- Hyprland window rules syntax
- systemd service options

## Benefits

- Current documentation (not training data cutoff)
- Version-specific information
- Accurate option types and defaults
- Reduces configuration errors

## Integration

Context7 should be consulted when:
- Creating new modules for unfamiliar programs
- Updating existing modules after package updates
- Debugging option type mismatches
- Exploring available configuration options

## Validation

After using Context7 documentation:
```bash
nix flake check --impure --accept-flake-config
```
