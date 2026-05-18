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
  nixConfig = {
    extra-substituters = [
      "https://shimboot-systemd-nixos.cachix.org"
      "https://numtide.cachix.org"
    ];
    extra-trusted-public-keys = [
      "shimboot-systemd-nixos.cachix.org-1:vCWmEtJq7hA2UOLN0s3njnGs9/EuX06kD7qOJMo2kAA="
      "numtide.cachix.org-1:2ps1kLBUWnLAnBIRTV6l6hEQuv59S++4Nux7496Z6tw="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Upstream ChromiumOS linux-firmware for driver harvesting
    # Full clone is large (~3GB) but cached in Nix store after first fetch
    linux-firmware = {
      url = "git+https://chromium.googlesource.com/chromiumos/third_party/linux-firmware?ref=master";
      flake = false;
    };
  };

  # Combine all outputs from modules
  outputs =
    {
      self,
      nixpkgs,
      linux-firmware,
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

      # Import nixpkgs-unstable for all packages
      pkgs = import nixpkgs { inherit system; };

      # Systemd 259.5 built with nixpkgs-unstable packages (zero old-nixpkgs imports)
      # All build deps (python3, meson, bison, openssl…) come from Hydra-cached unstable.
      # Only systemd itself compiles locally.
      #
      # Systemd 260+ requires mount_setattr (kernel 5.12), unavailable on
      # ChromeOS shim kernels. 259.x has graceful fallbacks.
      # Ref: https://github.com/ading2210/shimboot/issues/405
      systemdPackages = import ./flake_modules/systemd-259.nix {
        inherit pkgs;
        patchesDir = ./patches;
      };
      inherit (systemdPackages) systemd259 systemdMinimal259;

      # Import module outputs
      # Core system and development modules
      rawImageOutputs =
        board:
        import ./flake_modules/raw-image.nix {
          inherit
            self
            nixpkgs
            board
            systemd259
            ;
        };
      systemConfigurationOutputs = import ./flake_modules/system-configuration.nix {
        inherit
          self
          nixpkgs
          systemd259
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

      # dev-exp: Nix-first image assembly
      # These are the new prototype modules replacing assemble-final.sh orchestration
      harvestedDriversOutputs =
        board:
        import ./flake_modules/harvest-drivers.nix {
          inherit self nixpkgs board linux-firmware;
        };
      assembleImageOutputs =
        board:
        import ./flake_modules/assemble-image.nix {
          inherit
            self
            nixpkgs
            board
            systemd259
            ;
        };

      # Generate packages for each board
      boardPackages =
        board:
        (rawImageOutputs board).packages.${system} or { }
        // (chromeosSourcesOutputs board).packages.${system} or { }
        // (kernelExtractionOutputs board).packages.${system} or { }
        // (initramfsExtractionOutputs board).packages.${system} or { }
        // (initramfsPatchingOutputs board).packages.${system} or { }
        // (harvestedDriversOutputs board).packages.${system} or { }
        // (assembleImageOutputs board).packages.${system} or { };

      # Merge packages from all modules
      packages = {
        ${system} = nixpkgs.lib.foldl' (acc: board: acc // (boardPackages board)) {
          systemd = systemd259;
          systemdMinimal = systemdMinimal259;
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
      nixosModules = {
        # Full ChromeOS base configuration (boot, fs, hw, users, nix settings)
        # Wraps configuration.nix to inject systemd259.
        # Build-time udevadm verify uses nixpkgs-unstable's 260.1 udevadm;
        # runtime udevd is 259.5 via systemd.package = systemd259.
        # The version mismatch is benign: 259.5 warns on unknown OPTIONS,
        # gracefully ignores unknown tokens.
        chromeos = {
          imports = [ ./shimboot_config/base_configuration/configuration.nix ];
          _module.args = {
            inherit systemd259;
          };
        };

        # Shimboot options (shimboot.headless mkEnableOption)
        shimboot-options = ./shimboot_config/shimboot-options.nix;

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
