# raw-image.nix
#
# Purpose: Generate raw rootfs images for ChromeOS shimboot installation
#
# This module:
# - Builds raw rootfs images for base and headless configurations
# - Configures serial console logging and Nix garbage collection
# - Uses nixpkgs built-in image generation (nixos-generators upstreamed as of 25.05)
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

  # Helper function to create NixOS configuration for image generation
  # This works for both NixOS and non-NixOS builders
  mkImageConfiguration =
    { headless ? false }:
    let
      # Create a NixOS configuration with the image module
      nixosConfig = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ../shimboot_config/base_configuration/configuration.nix

          # Enable the image builder module from nixpkgs
          # This is the upstreamed nixos-generators functionality
          "${nixpkgs}/nixos/modules/image/images.nix"

          # Image configuration for raw-efi
          {
            nixpkgs.hostPlatform = system;
            boot.kernelParams = [ "console=ttyS0,115200" ];
          }
        ];
        specialArgs = {
          inherit
            self
            userConfig
            systemd257
            ;
          inherit (self) inputs;
          inherit headless;
        };
      };
    in
    nixosConfig.config.system.build.images.raw-efi;
in
{
  packages.${system} = {
    # Base system with desktop (Hyprland, LightDM)
    raw-rootfs-base = mkImageConfiguration { headless = false; };

    # Headless system for SSH-only access (no desktop)
    raw-rootfs-headless = mkImageConfiguration { headless = true; };
  };
}