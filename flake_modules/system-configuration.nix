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
  ...
}:
let
  system = "x86_64-linux";
  inherit (nixpkgs) lib;

  selectedProfile = import ../shimboot_config/selected-profile.nix;
  inherit (selectedProfile) profile;
  userConfig = import ../shimboot_config/profiles/${profile}/user-config.nix { };
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
            selectedProfile
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
          import ../shimboot_config/profiles/${profile}/main_configuration/home/home.nix;
      }
    )
  ];
in
{
  nixosConfigurations =
    let
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
              selectedProfile
              llm-agents
              ;
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
              selectedProfile
              llm-agents
              ;
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
              selectedProfile
              llm-agents
              ;
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
              selectedProfile
              llm-agents
              ;
          };
        };
      };
    in
    baseSet // compatRaw // compatShimboot;
}
