# raw-image.nix
#
# Purpose: Generate raw rootfs images for ChromeOS shimboot installation
#
# This module:
# - Builds full raw rootfs with Home Manager integration
# - Builds minimal raw rootfs with base configuration only
# - Configures serial console logging and Nix garbage collection
# - Auto-discovers and generates images for all profiles
{
  self,
  nixos-generators,
  home-manager,
  zen-browser,
  rose-pine-hyprcursor,
  noctalia,
  stylix,
  ...
}:
let
  system = "x86_64-linux";

  # Auto-discover available profiles
  profilesDir = ../shimboot_config/profiles;
  profileNames = builtins.attrNames (builtins.readDir profilesDir);

  # Generate user config for a given profile
  getUserConfig = profile: import ../shimboot_config/profiles/${profile}/user-config.nix { };

  # Create raw image packages for a single profile
  makeProfilePackages =
    profile:
    let
      userConfig = getUserConfig profile;
      selectedProfile = { inherit profile; };
    in
    {
      # Generate a raw image that includes the main configuration (reduces on-target build)
      "raw-rootfs-${profile}" = nixos-generators.nixosGenerate {
        inherit system;
        format = "raw";
        specialArgs = {
          inherit
            self
            zen-browser
            rose-pine-hyprcursor
            noctalia
            stylix
            userConfig
            selectedProfile
            ;
        };

        modules = [
          (
            { config, ... }:
            {
              nixpkgs.overlays = import ../overlays/overlays.nix config.nixpkgs.system;
            }
          )
        ]
        ++ [
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
              home-manager.users.${userConfig.user.username} =
                import ../shimboot_config/profiles/${profile}/main_configuration/home/home.nix;
            }
          )

          (_: {
            boot.kernelParams = [ "console=ttyS0,115200" ];

            nix.settings.experimental-features = [
              "nix-command"
              "flakes"
            ];

            nix.gc = {
              automatic = true;
              dates = "weekly";
              options = "--delete-older-than 30d";
            };
          })
        ];
      };

      "raw-rootfs-${profile}-minimal" = nixos-generators.nixosGenerate {
        inherit system;
        format = "raw";
        specialArgs = {
          inherit
            self
            zen-browser
            rose-pine-hyprcursor
            noctalia
            stylix
            userConfig
            selectedProfile
            ;
        };

        modules = [
          ../shimboot_config/base_configuration/configuration.nix

          (_: {
            boot.kernelParams = [ "console=ttyS0,115200" ];

            nix.settings.experimental-features = [
              "nix-command"
              "flakes"
            ];

            nix.gc = {
              automatic = true;
              dates = "weekly";
              options = "--delete-older-than 30d";
            };
          })
        ];
      };
    };

  # Merge all profile packages
  allPackages = nixos-generators.inputs.nixpkgs.lib.foldl' (
    acc: profile: acc // (makeProfilePackages profile)
  ) { } profileNames;
in
{
  packages.${system} = allPackages;
}
