{ self, nixpkgs, nixos-generators, ... }:

let
  system = "x86_64-linux";
  pkgs = nixpkgs.legacyPackages.${system};
in {
  packages.${system} = {
    # Generate a raw image with single partition rootfs
    raw-rootfs = nixos-generators.nixosGenerate {
      inherit system;
      format = "raw";
      
      modules = [
        # Import the base (required) shimboot configuration
        ../shimboot_config/base_configuration/configuration.nix
        
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