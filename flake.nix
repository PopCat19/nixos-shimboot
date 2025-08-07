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
      rawEfiImageOutputs = import ./flake_modules/raw-efi-image.nix { inherit self nixpkgs nixos-generators; };
      rawImageOutputs = import ./flake_modules/raw-image.nix { inherit self nixpkgs nixos-generators; };
      systemConfigurationOutputs = import ./flake_modules/system-configuration.nix { inherit self nixpkgs; };
      developmentEnvironmentOutputs = import ./flake_modules/development-environment.nix { inherit self nixpkgs; };
      initramfsPatchingOutputs = import ./flake_modules/initramfs-patching.nix { inherit self nixpkgs; };
      chromeosSourcesOutputs = import ./flake_modules/chromeos-sources.nix { inherit self nixpkgs; };
      initramfsPatchingTestOutputs = import ./flake_modules/initramfs-patching-test.nix { inherit self nixpkgs; };
      
      # Merge packages from all modules
      packages = {
        ${system} =
          (rawEfiImageOutputs.packages.${system} or {}) //
          (rawImageOutputs.packages.${system} or {}) //
          (initramfsPatchingOutputs.packages.${system} or {}) //
          (chromeosSourcesOutputs.packages.${system} or {}) //
          (initramfsPatchingTestOutputs.packages.${system} or {});
      };
      
      # Set default package to raw-rootfs
      defaultPackage.${system} = packages.${system}.raw-rootfs;
      
      # Merge devShells from all modules
      devShells = {
        ${system} =
          (developmentEnvironmentOutputs.devShells.${system} or {}) //
          (initramfsPatchingOutputs.devShells.${system} or {});
      };
      
      # Merge nixosConfigurations from all modules
      nixosConfigurations =
        systemConfigurationOutputs.nixosConfigurations or {};
        
      # Merge nixosModules from all modules
      nixosModules =
        initramfsPatchingOutputs.nixosModules or {};
        
    in {
      # Export all merged outputs
      inherit packages devShells nixosConfigurations nixosModules;
    };
}