{ self, nixpkgs, nixos-generators, ... }:

let
  system = "x86_64-linux";
  pkgs = nixpkgs.legacyPackages.${system};
  
  # Import partitioning module
  partitioning = import ./partitioning.nix { inherit self nixpkgs; };
  
  # Generate a basic NixOS system to extract rootfs
  nixosSystem = nixos-generators.nixosGenerate {
    inherit system;
    format = "raw";
    
    modules = [
      # Import the shimboot configuration
      ../shimboot_config/configuration.nix
      
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
in {
  packages.${system} = {
    # Generate a Chrome OS-style partitioned disk image
    chromeos-image = partitioning.createChromeOSImage {
      outputPath = "shimboot-chromeos.img";
      kernelPath = "${pkgs.linux}/bzImage";
      initramfsDir = ../bootloader;
      rootfsDir = nixosSystem;
      distroName = "nixos";
      partitionSizes = {
        stateful = 1;
        kernel = 32;
        bootloader = 20;
        rootfs = null; # Auto-calculate
      };
      extraSizeMB = 100;
    };
    
    # Keep the original raw-rootfs for compatibility
    raw-rootfs = nixosSystem;
    
    # Set default package to the Chrome OS-style image
    defaultPackage = self.packages.${system}.chromeos-image;
  };
}