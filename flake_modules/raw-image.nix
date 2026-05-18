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
  systemd259,
  systemdMinimal259,
  ...
}:
let
  system = "x86_64-linux";

  # Overlay to replace systemdMinimal with systemdMinimal259
  # This ensures udevadm verify uses the same version as the target systemd
  systemd259Overlay = _final: _prev: {
    systemdMinimal = systemdMinimal259;
  };

  # Import user config from flattened location
  userConfig = import ../shimboot_config/user-config.nix { };

  # Helper function to create NixOS configuration for image generation
  # This works for both NixOS and non-NixOS builders
  mkImageConfiguration =
    {
      headless ? false,
    }:
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

          # Apply overlay to replace systemdMinimal with 259.5 variant
          { nixpkgs.overlays = [ systemd259Overlay ]; }
        ]
        ++ nixpkgs.lib.optional headless { shimboot.headless = true; };
        specialArgs = {
          inherit
            self
            userConfig
            systemd259
            ;
          inherit (self) inputs;
        };
      };
    in
    nixosConfig.config.system.build.images.raw;
in
{
  packages.${system} = {
    # Base system with desktop (Hyprland, LightDM)
    raw-rootfs-base = mkImageConfiguration { headless = false; };

    # Headless system for SSH-only access (no desktop)
    raw-rootfs-headless = mkImageConfiguration { headless = true; };
  };
}
