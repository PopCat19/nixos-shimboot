# Flake Configuration
#
# Purpose: Main flake.nix defining inputs and outputs for nixos-shimboot (base branch)
# Dependencies: nixpkgs
# Related: shimboot_config/, flake_modules/
#
# This flake provides:
# - Raw image generation for ChromeOS boards (base config only)
# - System configurations (minimal, no desktop)
# - Development environment and tools
# - ChromeOS kernel/initramfs extraction and patching
#
# Note: This is the base branch. For full desktop config, use --config-branch default
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Pinned nixpkgs for systemd 257.9 package definition
    # We use the package from here but override stdenv to unstable's for glibc compat
    nixpkgs-systemd.url = "github:NixOS/nixpkgs/d3736636ac39ed678e557977b65d620ca75142d0";
  };

  # Combine all outputs from modules
  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-systemd,
      ...
    }:
    let
      # Import Cachix configuration
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

      # Import nixpkgs-unstable for stdenv (glibc 2.42)
      pkgs = import nixpkgs { inherit system; };

      # Import systemd from pinned nixpkgs, but override to use unstable's stdenv
      # This gives us systemd 257.9 package definition with glibc 2.42
      pkgsSystemd = import nixpkgs-systemd {
        inherit system;
        overlays = [
          (final: prev: {
            # Override systemd to use unstable's stdenv and add ChromeOS patch
            systemd = prev.systemd.override {
              stdenv = pkgs.stdenv;
            };
          })
        ];
      };

      # Overlay to use systemd 257.9 from pinned nixpkgs
      # systemd 258+ requires kernel >=5.10 (open_tree/move_mount syscalls)
      # See: https://github.com/PopCat19/nixos-shimboot/issues/405
      systemdOverlay = final: prev: {
        systemd = pkgsSystemd.systemd.overrideAttrs (old: {
          patches = (old.patches or [ ]) ++ [
            ./patches/systemd-mountpoint-util-chromeos.patch
          ];
        });
      };

      # Import module outputs
      # Core system and development modules
      rawImageOutputs =
        board:
        import ./flake_modules/raw-image.nix {
          inherit
            self
            nixpkgs
            board
            systemdOverlay
            ;
        };
      systemConfigurationOutputs = import ./flake_modules/system-configuration.nix {
        inherit
          self
          nixpkgs
          systemdOverlay
          ;
      };
      developmentEnvironmentOutputs = import ./flake_modules/development-environment.nix {
        inherit self nixpkgs;
      };

      # ChromeOS and patch_initramfs modules
      chromeosSourcesOutputs =
        board:
        import ./flake_modules/chromeos-sources.nix {
          inherit self nixpkgs board;
        };
      kernelExtractionOutputs =
        board:
        import ./flake_modules/patch_initramfs/kernel-extraction.nix {
          inherit self nixpkgs board;
        };
      initramfsExtractionOutputs =
        board:
        import ./flake_modules/patch_initramfs/initramfs-extraction.nix {
          inherit self nixpkgs board;
        };
      initramfsPatchingOutputs =
        board:
        import ./flake_modules/patch_initramfs/initramfs-patching.nix {
          inherit self nixpkgs board;
        };

      # Generate packages for each board
      boardPackages =
        board:
        (rawImageOutputs board).packages.${system} or { }
        // (chromeosSourcesOutputs board).packages.${system} or { }
        // (kernelExtractionOutputs board).packages.${system} or { }
        // (initramfsExtractionOutputs board).packages.${system} or { }
        // (initramfsPatchingOutputs board).packages.${system} or { };

      # Merge packages from all modules
      packages = {
        ${system} = nixpkgs.lib.foldl' (acc: board: acc // (boardPackages board)) {
          systemd = pkgsSystemd.systemd.overrideAttrs (old: {
            patches = (old.patches or [ ]) ++ [
              ./patches/systemd-mountpoint-util-chromeos.patch
            ];
          });
        } supportedBoards;
      };

      # Merge devShells from all modules
      devShells = {
        ${system} = developmentEnvironmentOutputs.devShells.${system} or { };
      };

      # Merge nixosConfigurations from all modules
      nixosConfigurations = systemConfigurationOutputs.nixosConfigurations or { };
    in
    {
      # Cachix configuration for binary cache
      inherit ((import ./flake_modules/cachix-config.nix { })) nixConfig;

      nixosModules = {
        # Full ChromeOS base configuration (boot, fs, hw, users, nix settings)
        # Note: systemd is overridden via systemdOverlay in flake.nix
        chromeos = ./shimboot_config/base_configuration/configuration.nix;

        # Granular modules for selective import
        nix-options = ./shimboot_config/nix-options.nix;
        raw-image = ./flake_modules/raw-image.nix;
        system-configuration = ./flake_modules/system-configuration.nix;
      };

      # Export all merged outputs
      formatter.${system} = nixpkgs.legacyPackages.${system}.nixfmt-tree;
      inherit
        packages
        devShells
        nixosConfigurations
        ;
    };
}
