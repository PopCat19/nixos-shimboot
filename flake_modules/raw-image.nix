{
  self,
  nixos-generators,
  home-manager,
  zen-browser,
  rose-pine-hyprcursor,
  noctalia,
  ...
}: let
  system = "x86_64-linux";
  userConfig = import ../shimboot_config/user-config.nix {};
in {
  packages.${system} = {
    # Generate a raw image that includes the main configuration (reduces on-target build)
    raw-rootfs = nixos-generators.nixosGenerate {
      inherit system;
      format = "raw";
      specialArgs = {inherit zen-browser rose-pine-hyprcursor noctalia;};

      modules =
        [
          # Apply overlays
          ({config, ...}: {
            nixpkgs.overlays = import ../overlays/overlays.nix config.nixpkgs.system;
          })
        ]
        ++ [
          # Use the main configuration (which itself imports base)
          ../shimboot_config/main_configuration/configuration.nix

          # Integrate Home Manager for user-level configuration like the full system build
          home-manager.nixosModules.home-manager
          ({pkgs, ...}: {
            home-manager.useGlobalPkgs = false;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = {
              inherit zen-browser rose-pine-hyprcursor userConfig;
              inherit (self) inputs;
            };
            home-manager.sharedModules = [
              (_: {
                nixpkgs.config.allowUnfree = true;
                nixpkgs.overlays = import ../overlays/overlays.nix pkgs.system;
                _module.args.userConfig = userConfig;
              })
            ];
            home-manager.users.${userConfig.user.username} = import ../shimboot_config/main_configuration/home/home.nix;
          })

          # Raw image specific configuration
          (_: {
            # Enable serial console logging
            boot.kernelParams = ["console=ttyS0,115200"];

            # Enable Nix flakes
            nix.settings.experimental-features = ["nix-command" "flakes"];

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
      specialArgs = {inherit zen-browser rose-pine-hyprcursor noctalia;};

      modules = [
        # Base-only configuration (standalone Hyprland via greetd)
        ../shimboot_config/base_configuration/configuration.nix

        # Raw image specific configuration
        (_: {
          # Enable serial console logging
          boot.kernelParams = ["console=ttyS0,115200"];

          # Enable Nix flakes
          nix.settings.experimental-features = ["nix-command" "flakes"];

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
