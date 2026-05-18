# system-configuration.nix
#
# Purpose: Define NixOS system configurations for building shimboot targets
#
# This module:
# - Exposes primary configuration (nixos-shimboot) with desktop
# - Exposes headless configuration (nixos-shimboot-headless) for SSH-only access
# - Provides compatibility aliases for legacy configuration names
# - Applies systemdMinimal259 overlay to fix udevadm verify version mismatch
{
  self,
  nixpkgs,
  systemd259,
  systemdMinimal259,
  ...
}:
let
  system = "x86_64-linux";

  # Import user config from flattened location
  userConfig = import ../shimboot_config/user-config.nix { };
  hn = userConfig.host.hostname;

  # Overlay to replace systemdMinimal with systemdMinimal259
  # This ensures udevadm verify uses the same version as the target systemd
  systemd259Overlay = _final: _prev: {
    systemdMinimal = systemdMinimal259;
  };

  # Base configuration - primary with desktop
  baseConfig = {
    inherit system;
    modules = [
      ../shimboot_config/base_configuration/configuration.nix
      # Apply overlay to replace systemdMinimal with 259.5 variant
      { nixpkgs.overlays = [ systemd259Overlay ]; }
    ];
    specialArgs = {
      inherit
        self
        userConfig
        systemd259
        ;
      inherit (self) inputs;
    };
  };

  # Headless configuration - SSH-only, no desktop
  headlessConfig = {
    inherit system;
    modules = [
      ../shimboot_config/base_configuration/configuration.nix
      { shimboot.headless = true; }
      # Apply overlay to replace systemdMinimal with 259.5 variant
      { nixpkgs.overlays = [ systemd259Overlay ]; }
    ];
    specialArgs = {
      inherit
        self
        userConfig
        systemd259
        ;
      inherit (self) inputs;
    };
  };

  # Helper to create NixOS system config
  mkConfig = config: nixpkgs.lib.nixosSystem config;

  # Primary configuration set
  primarySet = {
    "${hn}" = mkConfig baseConfig;
    "${hn}-headless" = mkConfig headlessConfig;
  };

  # Compatibility aliases for legacy names
  compatConfig = {
    nixos-user = mkConfig baseConfig;
    raw-efi-system = mkConfig baseConfig;
  };
in
{
  nixosConfigurations = primarySet // compatConfig;
}
