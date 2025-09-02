{ self, nixpkgs, nixos-generators, home-manager, ... }:

let
  system = "x86_64-linux";
  pkgs = nixpkgs.legacyPackages.${system};
in {
  packages.${system} = {
    # Generate a raw image that includes the main configuration (reduces on-target build)
    raw-rootfs = nixos-generators.nixosGenerate {
      inherit system;
      format = "raw";
      
      modules = [
        # Use the main configuration (which itself imports base)
        ../shimboot_config/main_configuration/configuration.nix

        # Integrate Home Manager for user-level configuration like the full system build
        home-manager.nixosModules.home-manager
        ({ config, pkgs, ... }: {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users."nixos-user" = import ../shimboot_config/main_configuration/home_modules/home.nix;
        })

        # Raw image specific configuration
        ({ config, pkgs, ... }: {
          # Enable serial console logging
          boot.kernelParams = [ "console=ttyS0,115200" ];
          
          # Enable Nix flakes
          nix.settings.experimental-features = [ "nix-command" "flakes" ];
          
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