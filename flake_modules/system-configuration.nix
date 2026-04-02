# system-configuration.nix
#
# Purpose: Define NixOS system configurations for building shimboot targets
#
# This module:
# - Exposes minimal and full NixOS configurations with Home Manager integration
# - Provides compatibility aliases for legacy configuration names
# - Configures Nix flakes, garbage collection, and proxy settings
{
  self,
  nixpkgs,
  home-manager,
  zen-browser,
  rose-pine-hyprcursor,
  noctalia,
  stylix,
  llm-agents,
  nixvim,
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

  mainModules = [
    ../shimboot_config/main_configuration/configuration.nix

    home-manager.nixosModules.home-manager

    (
      { pkgs, ... }:
      {
        home-manager.useGlobalPkgs = false;
        home-manager.useUserPackages = true;
        home-manager.extraSpecialArgs = {
          inherit
            zen-browser
            rose-pine-hyprcursor
            userConfig
            nixvim
            ;
          inherit (self) inputs;
        };

        home-manager.sharedModules = [
          (_: {
            nixpkgs.config.allowUnfree = true;
            nixpkgs.overlays = import ../overlays/overlays.nix pkgs.system;
            _module.args.userConfig = userConfig;
          })
        ];

        home-manager.users."${userConfig.user.username}" =
          import ../shimboot_config/main_configuration/home/home.nix;
      }
    )
  ];

  baseSet = {
    "${hn}-minimal" = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = baseModules;
      specialArgs = {
        inherit
          self
          zen-browser
          rose-pine-hyprcursor
          noctalia
          stylix
          userConfig
          llm-agents
          patchedSystemd
          ;
        inherit (self) inputs;
      };
    };

    "${hn}" = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = mainModules;
      specialArgs = {
        inherit
          self
          zen-browser
          rose-pine-hyprcursor
          noctalia
          stylix
          userConfig
          llm-agents
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
          zen-browser
          rose-pine-hyprcursor
          noctalia
          stylix
          userConfig
          llm-agents
          patchedSystemd
          ;
        inherit (self) inputs;
      };
    };
  };

  compatShimboot = lib.optionalAttrs (hn != "nixos-shimboot") {
    nixos-shimboot = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = mainModules;
      specialArgs = {
        inherit
          self
          zen-browser
          rose-pine-hyprcursor
          stylix
          userConfig
          llm-agents
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
