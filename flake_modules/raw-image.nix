# raw-image.nix
#
# Purpose: Generate raw rootfs images for ChromeOS shimboot installation
#
# This module:
# - Builds full raw rootfs with Home Manager integration
# - Builds minimal raw rootfs with base configuration only
# - Configures serial console logging and Nix garbage collection
# - Uses nixpkgs built-in image generation (nixos-generators upstreamed as of 25.05)
{
  self,
  nixpkgs,
  home-manager,
  zen-browser,
  rose-pine-hyprcursor,
  noctalia,
  stylix,
  ...
}:
let
  system = "x86_64-linux";

  # Import user config from flattened location
  userConfig = import ../shimboot_config/user-config.nix { };

  # Helper function to create NixOS configuration for image generation
  # This works for both NixOS and non-NixOS builders
  mkImageConfiguration =
    { modules }:
    let
      # Create a NixOS configuration with the image module
      nixosConfig = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit
            self
            zen-browser
            rose-pine-hyprcursor
            noctalia
            stylix
            userConfig
            ;
        };

        modules = modules ++ [
          # Enable the image builder module from nixpkgs
          # This is the upstreamed nixos-generators functionality
          "${nixpkgs}/nixos/modules/image/images.nix"

          # Image configuration for raw-efi
          {
            # The raw-efi variant is already defined in image.modules
            # We just need to access it via system.build.images.raw-efi
            nixpkgs.hostPlatform = system;
          }
        ];
      };
    in
    nixosConfig.config.system.build.images.raw-efi;
in
{
  packages.${system} = {
    # Generate a raw image that includes the main configuration (reduces on-target build)
    raw-rootfs = mkImageConfiguration {
      modules = [
        (
          { config, ... }:
          {
            nixpkgs.overlays = import ../overlays/overlays.nix config.nixpkgs.system;
          }
        )
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
              import ../shimboot_config/main_configuration/home/home.nix;
          }
        )

        (_: {
          boot.kernelParams = [ "console=ttyS0,115200" ];

          nix.settings.experimental-features = [
            "nix-command"
            "flakes"
          ];
        })
      ];
    };

    raw-rootfs-minimal = mkImageConfiguration {
      modules = [
        ../shimboot_config/base_configuration/configuration.nix

        (_: {
          boot.kernelParams = [ "console=ttyS0,115200" ];

          nix.settings.experimental-features = [
            "nix-command"
            "flakes"
          ];
        })
      ];
    };
  };
}
