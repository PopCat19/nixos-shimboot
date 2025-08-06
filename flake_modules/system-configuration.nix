{ self, nixpkgs, ... }:

let
  system = "x86_64-linux";
in {
  # NixOS configuration for building the system
  nixosConfigurations.raw-efi-system = nixpkgs.lib.nixosSystem {
    inherit system;
    modules = [
      ../shimboot_config/configuration.nix
      # Add raw-efi specific configuration
      ({ config, pkgs, ... }: {
        # Enable serial console logging (default for raw-efi)
        # To also log to display, add: boot.kernelParams = [ "console=tty0" ];
        
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
}