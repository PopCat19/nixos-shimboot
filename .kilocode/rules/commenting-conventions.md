# Commenting Conventions for Shimboot Project

This document outlines the commenting conventions used in the shimboot project to ensure code maintainability, readability, and effective collaboration with LLMs.

## General Principles

- **Purpose-driven comments**: Explain *why* code exists, not just *what* it does
- **Concise but informative**: Keep comments focused and relevant
- **Update with code changes**: Comments should remain accurate as code evolves
- **Avoid redundancy**: Don't comment obvious code; focus on complex logic

## Comment Styles

### Single-line Comments
Use `//` for single-line comments in most languages, `#` for shell scripts and Nix.

```nix
# Enable audio services for ChromeOS compatibility
services.pipewire.enable = true;
```

### Multi-line Comments
Use `/* */` for block comments when explaining complex sections.

```nix
/*
 * Hardware configuration for ChromeOS devices
 * - Enables necessary kernel modules for ARM/x86 compatibility
 * - Configures power management for extended battery life
 * - Sets up display drivers for various Chromebook models
 */
```

### Documentation Comments
Use triple-slash `///` for API documentation in Rust, or equivalent in other languages.

## When to Comment

### Always Comment:
- Module/file headers explaining purpose and scope
- Complex business logic or algorithms
- Workarounds for bugs or platform limitations
- Configuration decisions that might seem counterintuitive
- TODO items and FIXME notes

### Consider Commenting:
- Non-obvious code patterns
- Performance-critical sections
- Security-related configurations
- Integration points with external systems

### Don't Comment:
- Obvious code (e.g., `x = x + 1`)
- Temporary debug code (remove when done)
- Commented-out code (delete unless needed for reference)

## Comment Format Guidelines

### Module Headers
```nix
# Audio Configuration Module
#
# Purpose: Configure audio services for ChromeOS compatibility
# Dependencies: pipewire, alsa-utils
# Related: display.nix, hardware.nix
#
# This module enables:
# - PipeWire for modern audio routing
# - ALSA utilities for legacy compatibility
# - Bluetooth audio support
```

### Function/Method Comments
```nix
# Configure display settings for Hyprland
# Args:
#   config: NixOS configuration object
#   lib: Nix library functions
# Returns: Modified configuration with display settings
configureHyprland = { config, lib }: {
  # ... implementation
};
```

### Configuration Block Comments
```nix
# Networking configuration
networking = {
  # Use NetworkManager for ChromeOS-style network management
  networkmanager.enable = true;

  # Disable DHCP for static IP configurations on enterprise devices
  useDHCP = false;
};
```

### TODO/FIXME Comments
```nix
# TODO: Implement automatic display detection for new Chromebook models
# FIXME: Work around kernel bug affecting suspend on ARM devices
```

## Language-Specific Conventions

### Nix
- Use `#` for all comments
- Comment complex attribute sets and derivations
- Explain security implications of configurations

### Shell Scripts
- Use `#` for comments
- Comment script purpose, arguments, and exit codes
- Document error handling logic

### Rust (if applicable)
- Use `///` for public API documentation
- Use `//` for implementation comments
- Follow rustdoc conventions

## Best Practices

1. **Write comments as you code** - Don't add them as an afterthought
2. **Use consistent terminology** - Match project vocabulary
3. **Reference issues/PRs** - Link to relevant GitHub issues when applicable
4. **Keep comments current** - Update when refactoring code
5. **Use markdown in comments** - Simple formatting for readability

## Examples

### Good Comment
```nix
# Enable ZFS for advanced filesystem features
# Required for snapshot management and data integrity on high-end Chromebooks
boot.supportedFilesystems = [ "zfs" ];
```

### Bad Comment (too obvious)
```nix
# Set the hostname
networking.hostName = "chromebook";
```

### Good Comment (explains why)
```nix
# Disable mutable users to prevent accidental system modifications
# ChromeOS security model requires immutable user configurations
users.mutableUsers = false;
```

## Maintenance

- Review comments during code reviews
- Update comments when making significant changes
- Use `grep` to find outdated TODO/FIXME items
- Consider generating documentation from comments when appropriate

Following these conventions ensures that the codebase remains maintainable and that future contributors (human or AI) can quickly understand the intent and context of the code.