# system-configuration.nix
#
# Purpose: Define NixOS system configurations for building shimboot targets
#
# This module:
# - Exposes minimal and full NixOS configurations with Home Manager integration
# - Provides compatibility aliases for legacy configuration names
# - Configures Nix flakes, garbage collection, and proxy settings
# - Auto-discovers and generates configurations for all profiles
{
  self,
  nixpkgs,
  home-manager,
  zen-browser,
  rose-pine-hyprcursor,
  noctalia,
  stylix,
  llm-agents,
  ...
}:
let
  system = "x86_64-linux";
  inherit (nixpkgs) lib;

  # Auto-discover available profiles from shimboot_config/profiles directory
  profilesDir = ../shimboot_config/profiles;
  profileNames = builtins.attrNames (builtins.readDir profilesDir);

  # Generate user config for a given profile
  getUserConfig = profile: import ../shimboot_config/profiles/${profile}/user-config.nix { };

  # Create configuration set for a single profile
  makeProfileConfigurations =
    profile:
    let
      userConfig = getUserConfig profile;
      hn = userConfig.host.hostname;

      baseModules = [
        ../shimboot_config/base_configuration/configuration.nix

        (_: {
          nix.settings.experimental-features = [
            "nix-command"
            "flakes"
          ];

          nix.gc = {
            automatic = true;
            dates = "weekly";
            options = "--delete-older-than 30d";
          };

          proxy.enable = true;
        })
      ];

      mainModules = [
        ../shimboot_config/profiles/${profile}/main_configuration/configuration.nix

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
                ;
              selectedProfile = { inherit profile; };
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
              import ../shimboot_config/profiles/${profile}/main_configuration/home/home.nix;
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
              ;
            selectedProfile = { inherit profile; };
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
              ;
            selectedProfile = { inherit profile; };
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
              ;
            selectedProfile = { inherit profile; };
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
              ;
            selectedProfile = { inherit profile; };
          };
        };
      };
    in
    baseSet // compatRaw // compatShimboot;

  # Merge all profile configurations
  allConfigurations = lib.foldl' (
    acc: profile: acc // (makeProfileConfigurations profile)
  ) { } profileNames;
in
{
  nixosConfigurations = allConfigurations;
}
