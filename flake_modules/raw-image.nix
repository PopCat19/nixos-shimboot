# Raw Image Generation Module
#
# Purpose: Generate raw disk images for ChromeOS boards
# Dependencies: nixos-generators, modules/, hosts/
# Related: flake.nix
#
# This module:
# - Generates full raw image with desktop environment
# - Generates minimal raw image with base configuration only
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
  vars = import ../vars;
in
{
  packages.${system} = {
    # Generate a raw image that includes the main configuration (reduces on-target build)
    raw-rootfs = nixos-generators.nixosGenerate {
      inherit system;
      format = "raw";
      specialArgs = {
        inherit
          zen-browser
          rose-pine-hyprcursor
          noctalia
          stylix
          vars
          ;
      };

      modules = [
        # Apply overlays
        (
          { config, ... }:
          {
            nixpkgs.overlays = import ../overlays/overlays.nix config.nixpkgs.system;
          }
        )
      ]
      ++ [
        # Use the new modular structure
        ../modules/nixos/core
        ../modules/nixos/desktop
        ../modules/nixos/hardware
        ../modules/nixos/profiles/shimboot

        # Integrate Home Manager for user-level configuration like the full system build
        home-manager.nixosModules.home-manager
        (
          { pkgs, ... }:
          {
            home-manager.useGlobalPkgs = false;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = {
              inherit zen-browser rose-pine-hyprcursor vars;
              inherit (self) inputs;
            };
            home-manager.sharedModules = [
              (_: {
                nixpkgs.config.allowUnfree = true;
                nixpkgs.overlays = import ../overlays/overlays.nix pkgs.system;
                _module.args.vars = vars;
              })
            ];
            home-manager.users.${vars.username} =
              import ../hosts/shimboot/home.nix;
          }
        )

        # Raw image specific configuration
        (_: {
          # Enable serial console logging
          boot.kernelParams = [ "console=ttyS0,115200" ];

          # Enable Nix flakes
          nix.settings.experimental-features = [
            "nix-command"
            "flakes"
          ];

          # Enable automatic garbage collection
          nix.gc = {
            automatic = true;
            dates = "weekly";
            options = "--delete-older-than 30d";
          };
        })
      ];
    };

    # Minimal/base-only raw image (no Home Manager, base configuration only)
    raw-rootfs-minimal = nixos-generators.nixosGenerate {
      inherit system;
      format = "raw";
      specialArgs = {
        inherit
          zen-browser
          rose-pine-hyprcursor
          noctalia
          stylix
          vars
          ;
      };

      modules = [
        # Base-only configuration using new modular structure
        ../modules/nixos/core
        ../modules/nixos/hardware

        # Raw image specific configuration
        (_: {
          # Enable serial console logging
          boot.kernelParams = [ "console=ttyS0,115200" ];

          # Enable Nix flakes
          nix.settings.experimental-features = [
            "nix-command"
            "flakes"
          ];

          # Enable automatic garbage collection
          nix.gc = {
            automatic = true;
            dates = "weekly";
            options = "--delete-older-than 30d";
          };
        })
      ];
    };
  };
}
