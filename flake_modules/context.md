# Context

- `assemble-image.nix` — Build complete ChromeOS shimboot disk image using systemd-repart
- `cachix-config.nix` — Provides Cachix binary cache configuration
- `chromeos-sources.nix` — Provides ChromeOS source overrides for NixOS
- `development-environment.nix` — Provides development environment flake outputs
- `harvest-drivers.nix` — Extract ChromeOS kernel modules and firmware from shim/recovery images
- `raw-image.nix` — Provides raw disk image building
- `system-configuration.nix` — Provides NixOS system configuration module
- `systemd-259.nix` — Build systemd 259.5 using nixpkgs-unstable packages