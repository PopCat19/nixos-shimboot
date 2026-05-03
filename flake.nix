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

      # Import systemd from pinned nixpkgs for systemd 257.9
      # Systemd 258+ uses open_tree/move_mount syscalls unavailable on older upstream
# kernels, but tested working on dedede (5.4.85) — per-board compat varies
      # See: https://github.com/PopCat19/nixos-shimboot/issues/405
      pkgsSystemd = import nixpkgs-systemd { inherit system; };

      # Systemd 257.9 with ChromeOS patch and missing unit stubs
      # Built with unstable's stdenv to match glibc version for initramfs compatibility
      # Passed via specialArgs, not overlay (avoids cross-version function arg issues)
      systemd257 =
        (pkgsSystemd.systemd.override {
          # Use unstable's stdenv to get glibc 2.42 matching rest of initramfs
          inherit (pkgs) stdenv;
        }).overrideAttrs
          (old: {
            patches = (old.patches or [ ]) ++ [
              ./patches/systemd-mountpoint-util-chromeos.patch
            ];
            # Add passthru attributes expected by nixos-unstable modules
            # Note: withTpm2Units=false to avoid missing systemd-tpm2-clear.service (not in 257.9)
            passthru = old.passthru or { } // {
              withLogind = true;
              withNspawn = true;
              withVconsole = true;
              withTpm2Units = false;
              withPortabled = false;
              withSysupdate = false;
            };
            # Ensure udevadm is available for verification
            # systemdMinimalMinimal variant for udev rules builds
            mesonFlags = (old.mesonFlags or [ ]) ++ [
              "-Dudev=true"
            ];
            # Create stub files for units added in systemd 258+ but expected by nixos-unstable
            postInstall = (old.postInstall or "") + ''
              # Auto-generate stubs for units expected by nixos-unstable but missing in 257.9
              # Units added in systemd 258+
              MISSING_UNITS="breakpoint-pre-udev.service breakpoint-pre-basic.service breakpoint-pre-mount.service breakpoint-pre-switch-root.service systemd-factory-reset-complete.service factory-reset-now.target"

              for unit in $MISSING_UNITS; do
                if [ ! -e "$out/example/systemd/system/$unit" ]; then
                  name=$(echo "$unit" | sed 's/\.[^.]*$//')
                  printf "[Unit]\nDescription=%s (stub - not in systemd 257.9)\n" "$name" > "$out/example/systemd/system/$unit"
                fi
              done

              # Factory-reset setup
              mkdir -p $out/example/systemd/system/factory-reset.target.wants

              # Binaries added in systemd 258+
              MISSING_BINS="systemd-factory-reset system-generators/systemd-factory-reset-generator"

              mkdir -p $out/lib/systemd/system-generators
              for bin in $MISSING_BINS; do
                if [ ! -e "$out/lib/systemd/$bin" ]; then
                  printf '#!/bin/sh\n# Stub - not available in systemd 257.9\nexit 0\n' > "$out/lib/systemd/$bin"
                  chmod +x "$out/lib/systemd/$bin"
                fi
              done
            '';
          });

      # SystemdMinimal 257.9 for udev rules verification
      # Matches systemdMinimal override pattern from nixpkgs but using pinned 257.9
      # This ensures udevadm verify uses the same version as the target systemd
      # Note: Parameters must match those available in pinned nixpkgs-systemd
      systemdMinimal257 =
        (pkgsSystemd.systemd.override {
          inherit (pkgs) stdenv;
          pname = "systemd-minimal-257";
          withAcl = false;
          withAnalyze = false;
          withApparmor = false;
          withAudit = false;
          withCompression = false;
          withCoredump = false;
          withCryptsetup = false;
          withRepart = false;
          withDocumentation = false;
          withEfi = false;
          withFido2 = false;
          withFirstboot = false;
          withGcrypt = false;
          withHostnamed = false;
          withHomed = false;
          withHwdb = false;
          withImportd = false;
          withKernelInstall = false;
          withLibBPF = false;
          withLibidn2 = false;
          withLocaled = false;
          withLogind = false;
          withMachined = false;
          withNetworkd = false;
          withNss = false;
          withOomd = false;
          withOpenSSL = false;
          withPam = false;
          withPasswordQuality = false;
          withPCRE2 = false;
          withPolkit = false;
          withPortabled = false;
          withQrencode = false;
          withRemote = false;
          withResolved = false;
          withShellCompletions = false;
          withSysusers = false;
          withSysupdate = false;
          withTimedated = false;
          withTimesyncd = false;
          withTpm2Tss = false;
          withUkify = false;
          withUserDb = false;
          withUtmp = false;
          # withVConsole not available in pinned nixpkgs-systemd
          withVmspawn = false;
          withTests = false;
        }).overrideAttrs (old: {
          patches = (old.patches or [ ]) ++ [
            ./patches/systemd-mountpoint-util-chromeos.patch
          ];
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
          systemdMinimal257
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
          systemd = systemd257;
          systemdMinimal = systemdMinimal257;
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
        # Wraps configuration.nix to inject systemd257 and systemdMinimal257 overlay
        # so consumers importing this module don't need to provide them separately
        chromeos = {
          imports = [ ./shimboot_config/base_configuration/configuration.nix ];
          _module.args = {
            systemd257 = systemd257;
            systemdMinimal257 = systemdMinimal257;
          };
          # Apply overlay to replace systemdMinimal with 257.9 variant
          # This ensures udevadm verify uses the correct systemd version
          nixpkgs.overlays = [
            (final: prev: { systemdMinimal = systemdMinimal257; })
          ];
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
