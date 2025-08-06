{ self, nixpkgs, nixos-generators, ... }:

let
  system = "x86_64-linux";
  pkgs = nixpkgs.legacyPackages.${system};
in {
  packages.${system} = {
    # Generate a raw-efi image for physical hardware with EFI support
    raw-efi = nixos-generators.nixosGenerate {
      inherit system;
      format = "raw-efi";
      
      # Optional: Set disk size in MB (default is automatic sizing)
      # specialArgs = {
      #   diskSize = 20 * 1024; # 20GB
      # };
      
      modules = [
        # Import the shimboot configuration
        ../shimboot_config/configuration.nix
        
        # Raw-efi specific configuration
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
  };
}