# raw-image.nix
#
# Purpose: Generate raw rootfs images for ChromeOS shimboot installation
#
# This module:
# - Builds minimal raw rootfs with base configuration only (base branch)
# - Configures serial console logging and Nix garbage collection
# - Uses nixpkgs built-in image generation (nixos-generators upstreamed as of 25.05)
{
  self,
  nixpkgs,
  patchedSystemd,
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
            userConfig
            patchedSystemd
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
    # Base branch: minimal rootfs only
    # For full rootfs, use --config-branch with default or popcat19-dev
    raw-rootfs-minimal = mkImageConfiguration {
      modules = [
        ../shimboot_config/base_configuration/configuration.nix

        (_: {
          boot.kernelParams = [ "console=ttyS0,115200" ];
        })
      ];
    };
  };
}
