# system-configuration.nix
#
# Purpose: Define NixOS system configurations for building shimboot targets
#
# This module:
# - Exposes minimal NixOS configurations (base only, no desktop)
# - Provides compatibility aliases for legacy configuration names
# - Configures Nix flakes, garbage collection, and proxy settings
{
  self,
  nixpkgs,
  patchedSystemd,
  ...
}:
let
  system = "x86_64-linux";
  inherit (nixpkgs) lib;

  # Import user config from flattened location
  userConfig = import ../shimboot_config/user-config.nix { };
  hn = userConfig.host.hostname;

  baseModules = [
    ../shimboot_config/base_configuration/configuration.nix

    (_: {
      nix.settings.experimental-features = [
        "nix-command"
        "flakes"
      ];
    })
  ];

  baseSet = {
    "${hn}-minimal" = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = baseModules;
      specialArgs = {
        inherit
          self
          userConfig
          patchedSystemd
          ;
        inherit (self) inputs;
      };
    };

    # Alias for backward compatibility - same as minimal on base branches
    "${hn}" = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = baseModules;
      specialArgs = {
        inherit
          self
          userConfig
          patchedSystemd
          ;
        inherit (self) inputs;
      };
    };
  };

  compatRaw = lib.optionalAttrs (hn != "raw-efi-system") {
    raw-efi-system = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = baseModules;
      specialArgs = {
        inherit
          self
          userConfig
          patchedSystemd
          ;
        inherit (self) inputs;
      };
    };
  };

  compatShimboot = lib.optionalAttrs (hn != "nixos-shimboot") {
    nixos-shimboot = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = baseModules;
      specialArgs = {
        inherit
          self
          userConfig
          patchedSystemd
          ;
        inherit (self) inputs;
      };
    };
  };
in
{
  nixosConfigurations = baseSet // compatRaw // compatShimboot;
}
