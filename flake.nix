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

    # Pinned nixpkgs for systemd 257.9 — the ceiling for shim kernels <5.10.
    # systemd 258+ requires mount_setattr (kernel 5.12), unavailable on
    # ChromeOS shim kernels. 257.9 has graceful fallbacks and working
    # systemd-user-sessions. Built via overrideAttrs (no custom derivation).
    # Ref: https://github.com/ading2210/shimboot/issues/405
    nixpkgs-systemd.url = "github:NixOS/nixpkgs/d3736636ac39ed678e557977b65d620ca75142d0";

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
      nixpkgs-systemd,
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

      # Pinned systemd 257.9 via overrideAttrs — the same approach gen 117 used.
      # Keeps native build config (PAM on → systemd-user-sessions binary built,
      # proper unit templates, wants symlinks). Only adds ChromeOS patches.
      #
      # Ceiling: 259.x (260 requires mount_setattr, kernel 5.12).
      # 257.9 proven working on dedede 5.4.85, octopus 4.14.x.
      # Ref: https://github.com/ading2210/shimboot/issues/405
      pkgsSystemd = import nixpkgs-systemd { inherit system; };
      # Shimboot-specific patches applied on top of nixpkgs systemd.
      #
      # The pidfd-spawn → posix_spawn fallback is no longer needed here:
      # the pinned nixpkgs systemd 257.9 source already handles it via the
      # clone_support state machine in posix_spawn_wrapper() (see
      # https://github.com/NixOS/nixpkgs/commit/d3736636ac39ed678e557977b65d620ca75142d0).
      # The earlier shimboot-specific patch no longer applies because that
      # function was restructured — CI cachix-systemd failed with
      # "Hunk #1 FAILED at 2208" on every run since 2026-05. See
      # patches/systemd-process-util-pidfd-fallback.patch for the obsolete
      # original.
      systemd257 = pkgsSystemd.systemd.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [
          ./patches/systemd-mountpoint-util-chromeos.patch
        ];
        # nixpkgs-unstable logind.nix reads these passthru attrs;
        # the pinned nixpkgs's systemd predates that convention.
        passthru = (old.passthru or { }) // {
          withLogind = true;
          withHostnamed = true;
          withLocaled = true;
          withTimedated = true;
          withNetworkd = true;
          withResolved = true;
          withPortabled = true;
          withHomed = false;
          withImportd = false;
          withMachined = false;
          withCryptsetup = true;
          withRepart = true;
          withSysupdate = false;
          withBootloader = false;
          withEfi = false;
          withFido2 = false;
          withTpm2Tss = false;
          withKmod = true;
          withNspawn = true;
          withUtmp = true;
          withVconsole = true;
          withTpm2Units = false;
          interfaceVersion = 2;
          inherit (pkgsSystemd) util-linux;
          inherit (pkgsSystemd) kmod;
          inherit (pkgsSystemd) kbd;
        };
      });

      # Import module outputs
      # Core system and development modules
      rawImageOutputs =
        board:
        import ./flake_modules/raw-image.nix {
          inherit
            self
            nixpkgs
            board
            systemd257
            ;
        };
      systemConfigurationOutputs = import ./flake_modules/system-configuration.nix {
        inherit
          self
          nixpkgs
          systemd257
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
          inherit
            self
            nixpkgs
            board
            linux-firmware
            ;
        };
      assembleImageOutputs =
        board:
        import ./flake_modules/assemble-image.nix {
          inherit
            self
            nixpkgs
            board
            systemd257
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
          systemd = systemd257;
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
        # Wraps configuration.nix to inject systemd257.
        chromeos = {
          imports = [ ./shimboot_config/base_configuration/configuration.nix ];
          _module.args = {
            inherit systemd257;
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
