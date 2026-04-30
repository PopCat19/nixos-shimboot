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

    # Stable nixpkgs for systemd 257.x package (258+ requires kernel >=5.10)
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.05";
  };

  # Combine all outputs from modules
  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-stable,
      ...
    }:
    let
      system = "x86_64-linux";

      supportedBoards = [
        "dedede"
        "octopus"
        "zork"
        "nissa"
        "hatch"
        "grunt"
        "snappy"
      ];

      # Unstable for main packages
      pkgs = import nixpkgs { inherit system; };

      # Stable for systemd 257.x (258+ requires kernel >=5.10 for open_tree/move_mount syscalls)
      pkgsStable = import nixpkgs-stable { inherit system; };

      # Systemd 257.x from nixos-25.05 stable with ChromeOS mount patch.
      # Uses unstable's modules with suppressedSystemUnits for missing 258+ units.
      #
      # IMPORTANT: Must override stdenv to unstable's glibc — the rest of the
      # system (initrd, activation scripts, NixOS modules) links against
      # unstable's glibc 2.42+. Without this override, systemd257 links against
      # stable's older glibc, causing runtime failures for systemctl, journalctl,
      # and other systemd tools (they silently fail to load at runtime).
      #
      # Stub files: unstable's initrd.nix references binaries that don't exist in 257.
      # We create dummy files to satisfy the initrd builder. These are harmless as
      # the corresponding units are suppressed in systemd-patch.nix.
      systemd257 = (pkgsStable.systemd.override { inherit (pkgs) stdenv; }).overrideAttrs (old: {
        __structuredAttrs = true; # Required by unstable stdenv when separateDebugInfo + allowedRequisites are set
        patches = (old.patches or [ ]) ++ [
          ./patches/systemd-mountpoint-util-chromeos.patch
        ];
        postInstall = (old.postInstall or "") + ''
          # Create stubs for binaries/units that unstable's initrd.nix expects but 257 lacks
          # Corresponding units are suppressed via systemd.suppressedUnits in systemd-patch.nix
          for f in \
            $out/lib/systemd/systemd-factory-reset \
            $out/lib/systemd/system-generators/systemd-factory-reset-generator
          do
            mkdir -p "$(dirname "$f")"
            echo '#!/bin/sh' > "$f"
            echo 'exit 0' >> "$f"
            chmod +x "$f"
          done

          # Create stub .wants directory for factory-reset (258+ only has this)
          mkdir -p $out/example/systemd/system/factory-reset.target.wants
        '';
      });

      # Extend passthru directly - overrideAttrs doesn't preserve it properly.
      # These attributes exist in unstable's systemd but not in 25.05 stable.
      # Note: passthru attributes must ALSO be spread at the top level for direct access.
      systemd257Final = systemd257 // {
        passthru = (systemd257.passthru or { }) // {
          inherit (pkgs.systemd.passthru or { })
            withLogind
            withNspawn
            withSysupdate;
        };
      } // {
        # Spread passthru additions to top level for direct access (e.g. pkg.withLogind)
        inherit (pkgs.systemd.passthru or { })
          withLogind
          withNspawn
          withSysupdate;
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
            ;
          systemd257 = systemd257Final;
        };
      systemConfigurationOutputs = import ./flake_modules/system-configuration.nix {
        inherit
          self
          nixpkgs
          ;
        systemd257 = systemd257Final;
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
          systemd = systemd257Final;
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
        # Wraps configuration.nix to inject systemd257 via _module.args
        # so consumers importing this module don't need to provide it separately
        chromeos = {
          imports = [ ./shimboot_config/base_configuration/configuration.nix ];
          _module.args.systemd257 = systemd257Final;
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
