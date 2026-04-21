# system-configuration.nix
#
# Purpose: Define NixOS system configurations for building shimboot targets
#
# This module:
# - Exposes primary configuration (nixos-shimboot) with desktop
# - Exposes headless configuration (nixos-shimboot-headless) for SSH-only access
# - Provides compatibility aliases for legacy configuration names
{
  self,
  nixpkgs,
  systemd257,
  ...
}:
let
  system = "x86_64-linux";

  # Import user config from flattened location
  userConfig = import ../shimboot_config/user-config.nix { };
  hn = userConfig.host.hostname;

  # Base configuration - primary with desktop
  baseConfig = {
    inherit system;
    modules = [ ../shimboot_config/base_configuration/configuration.nix ];
    specialArgs = {
      inherit
        self
        userConfig
        systemd257
        ;
      inherit (self) inputs;
      headless = false;
    };
  };

  # Headless configuration - SSH-only, no desktop
  headlessConfig = {
    inherit system;
    modules = [ ../shimboot_config/base_configuration/configuration.nix ];
    specialArgs = {
      inherit
        self
        userConfig
        systemd257
        ;
      inherit (self) inputs;
      headless = true;
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