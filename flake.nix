{
  # Import inputs from inputs module
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  
  description = "NixOS configuration for raw image generation";

  # Combine all outputs from modules
  outputs = { self, nixpkgs, nixos-generators, ... }:
    let
      system = "x86_64-linux";
      
      # Import all module outputs
      rawImageOutputs = import ./flake_modules/raw-image.nix { inherit self nixpkgs nixos-generators; };
      systemConfigurationOutputs = import ./flake_modules/system-configuration.nix { inherit self nixpkgs; };
      developmentEnvironmentOutputs = import ./flake_modules/development-environment.nix { inherit self nixpkgs; };
      kernelExtractionOutputs = import ./flake_modules/patch_initramfs/kernel-extraction.nix { inherit self nixpkgs; };
      initramfsExtractionOutputs = import ./flake_modules/patch_initramfs/initramfs-extraction.nix { inherit self nixpkgs; };
      chromeosSourcesOutputs = import ./flake_modules/chromeos-sources.nix { inherit self nixpkgs; };
      
      # Merge packages from all modules
      packages = {
        ${system} =
          (rawImageOutputs.packages.${system} or {}) //
          (kernelExtractionOutputs.packages.${system} or {}) //
          (initramfsExtractionOutputs.packages.${system} or {}) //
          (chromeosSourcesOutputs.packages.${system} or {});
      };
      
      # Set default package to raw-rootfs
      defaultPackage.${system} = packages.${system}.raw-rootfs;
      
      # Merge devShells from all modules
      devShells = {
        ${system} =
          (developmentEnvironmentOutputs.devShells.${system} or {});
      };
      
      # Merge nixosConfigurations from all modules
      nixosConfigurations =
        systemConfigurationOutputs.nixosConfigurations or {};
        
      # Merge nixosModules from all modules
      nixosModules = {};
        
    in {
      # Export all merged outputs
      inherit packages devShells nixosConfigurations nixosModules;
    };
}