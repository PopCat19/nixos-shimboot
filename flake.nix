# Flake Configuration
#
# Purpose: Main flake.nix defining inputs and outputs for nixos-shimboot
# Dependencies: nixpkgs, home-manager, zen-browser, rose-pine-hyprcursor
# Related: shimboot_config/, flake_modules/
#
# This flake provides:
# - Raw image generation for ChromeOS boards
# - System configurations with home-manager integration
# - Development environment and tools
# - ChromeOS kernel/initramfs extraction and patching
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    rose-pine-hyprcursor = {
      url = "github:ndom91/rose-pine-hyprcursor";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # Combine all outputs from modules
  outputs = {
    self,
    nixpkgs,
    nixos-generators,
    home-manager,
    zen-browser,
    rose-pine-hyprcursor,
    ...
  }: let
    system = "x86_64-linux";

    # Supported ChromeOS boards
    supportedBoards = [
      "dedede"
      "octopus"
      "zork"
      "nissa"
      "hatch"
      "grunt"
      "snappy"
    ];

    # Import user configuration
    userConfig = import ./shimboot_config/user-config.nix {};
    # Extract username for easier access
    username = userConfig.user.username;

    # Import module outputs
    # Core system and development modules
    rawImageOutputs = board:
      import ./flake_modules/raw-image.nix {
        inherit self nixpkgs nixos-generators home-manager zen-browser rose-pine-hyprcursor board;
      };
    systemConfigurationOutputs = import ./flake_modules/system-configuration.nix {inherit self nixpkgs home-manager zen-browser rose-pine-hyprcursor;};
    developmentEnvironmentOutputs = import ./flake_modules/development-environment.nix {inherit self nixpkgs;};

    # ChromeOS and patch_initramfs modules
    chromeosSourcesOutputs = board:
      import ./flake_modules/chromeos-sources.nix {
        inherit self nixpkgs board;
      };
    kernelExtractionOutputs = board:
      import ./flake_modules/patch_initramfs/kernel-extraction.nix {
        inherit self nixpkgs board;
      };
    initramfsExtractionOutputs = board:
      import ./flake_modules/patch_initramfs/initramfs-extraction.nix {
        inherit self nixpkgs board;
      };
    initramfsPatchingOutputs = board:
      import ./flake_modules/patch_initramfs/initramfs-patching.nix {
        inherit self nixpkgs board;
      };

    # Generate packages for each board
    boardPackages = board:
      (rawImageOutputs board).packages.${system} or {}
      // (chromeosSourcesOutputs board).packages.${system} or {}
      // (kernelExtractionOutputs board).packages.${system} or {}
      // (initramfsExtractionOutputs board).packages.${system} or {}
      // (initramfsPatchingOutputs board).packages.${system} or {};

    # Merge packages from all modules
    packages = {
      ${system} = nixpkgs.lib.foldl' (acc: board: acc // (boardPackages board)) {} supportedBoards;
    };

    # Import overlays
    overlays = import ./overlays/overlays.nix;

    # Set default package to dedede raw-rootfs
    defaultPackage.${system} = packages.${system}.raw-rootfs-dedede or packages.${system}.raw-rootfs;

    # Merge devShells from all modules
    devShells = {
      ${system} =
        developmentEnvironmentOutputs.devShells.${system} or {};
    };

    # Merge nixosConfigurations from all modules
    nixosConfigurations =
      systemConfigurationOutputs.nixosConfigurations or {};

    # Merge nixosModules from all modules
    nixosModules = {};
  in {
    # Export all merged outputs
    formatter.${system} = nixpkgs.legacyPackages.${system}.alejandra;
    inherit packages devShells nixosConfigurations nixosModules;
  };
}
