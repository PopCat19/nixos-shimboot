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

    # Pinned nixpkgs for systemd 259.5 package definition
    # We use the package from here but override stdenv to unstable's for glibc compat
    # 259.x is the last version that supports kernels < 5.10 (close_range, STATX_MNT_ID,
    # MS_NOSYMFOLLOW still have fallbacks). 260 removed fallbacks for open_tree/move_mount.
    # See: https://github.com/systemd/systemd/blob/v260/NEWS
    nixpkgs-259.url = "github:NixOS/nixpkgs/666304f6f14b59f7e6edb360e1fc161b8ebf6a21";
  };

  # Combine all outputs from modules
  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-259,
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

      # Import systemd from pinned nixpkgs for systemd 259.5
      # Systemd 260+ requires mount_setattr (kernel 5.12), unavailable on
      # ChromeOS shim kernels. 259.x works on dedede (5.4.85) and has graceful
      # fallbacks for all kernel features below baseline (close_range, STATX_MNT_ID,
      # MS_NOSYMFOLLOW, open_tree/move_mount).
      # Ref: https://github.com/ading2210/shimboot/issues/405
      pkgsSystemd259 = import nixpkgs-259 { inherit system; };

      # Systemd 259.5 with ChromeOS + pidfd_spawn patches
      # Built with unstable's stdenv to match glibc version for initramfs compatibility
      # Passed via specialArgs, not overlay (avoids cross-version function arg issues)
      systemd259 =
        (pkgsSystemd259.systemd.override {
          # Use unstable's stdenv to get glibc 2.42 matching rest of initramfs
          inherit (pkgs) stdenv;
        }).overrideAttrs
          (old: {
            patches = (old.patches or [ ]) ++ [
              ./patches/systemd-mountpoint-util-chromeos.patch
              ./patches/systemd-process-util-pidfd-fallback.patch
            ];
            # Add passthru attributes expected by nixos-unstable modules
            passthru = old.passthru or { } // {
              withLogind = true;
              withNspawn = true;
              withVconsole = true;
              withTpm2Units = false;
              withPortabled = false;
              withSysupdate = false;
            };
            # Create NOOP stubs for units added after 259.5 but expected by nixos-unstable
            postInstall = (old.postInstall or "") + ''
              UNITDIR="$out/example/systemd/system"
              mkdir -p "$UNITDIR"

              for unit in breakpoint-pre-udev.service breakpoint-pre-basic.service breakpoint-pre-mount.service breakpoint-pre-switch-root.service systemd-factory-reset-complete.service systemd-journalctl@.service; do
                if [ ! -e "$UNITDIR/$unit" ]; then
                  name=$(echo "$unit" | sed 's/\..*$//')
                  printf '[Unit]\nDescription=%s (stub - not in 259.5)\nDefaultDependencies=no\nRefuseManualStart=yes\n\n[Service]\nType=oneshot\nExecStart=/bin/true\nRemainAfterExit=yes\n' "$name" > "$UNITDIR/$unit"
                fi
              done

              if [ ! -e "$UNITDIR/factory-reset-now.target" ]; then
                printf '[Unit]\nDescription=factory-reset-now (stub - not in 259.5)\nRefuseManualStart=yes\n' > "$UNITDIR/factory-reset-now.target"
              fi

              if [ ! -e "$UNITDIR/systemd-journalctl.socket" ]; then
                printf '[Unit]\nDescription=systemd-journalctl (stub - not in 259.5)\nDefaultDependencies=no\nBefore=sockets.target\n\n[Socket]\nListenStream=/run/systemd/io.systemd.JournalAccess\nSymlinks=/run/varlink/registry/io.systemd.JournalAccess\nFileDescriptorName=varlink\n' > "$UNITDIR/systemd-journalctl.socket"
              fi

              mkdir -p "$UNITDIR/factory-reset.target.wants"

              BINDIR="$out/lib/systemd"
              mkdir -p "$BINDIR/system-generators"
              for bin in systemd-factory-reset system-generators/systemd-factory-reset-generator; do
                if [ ! -e "$BINDIR/$bin" ]; then
                  printf '#!/bin/sh\n# Stub - not available in systemd 259.5\nexit 0\n' > "$BINDIR/$bin"
                  chmod +x "$BINDIR/$bin"
                fi
              done
            '';
          });

      # SystemdMinimal 259.5 for udev rules verification
      # Matches systemdMinimal override pattern from nixpkgs but using pinned 259.5
      # This ensures udevadm verify uses the same version as the target systemd
      systemdMinimal259 =
        (pkgsSystemd259.systemd.override {
          inherit (pkgs) stdenv;
          pname = "systemd-minimal-259";
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
          # withVConsole not available in pinned nixpkgs-259
          withVmspawn = false;
          withTests = false;
        }).overrideAttrs
          (old: {
            patches = (old.patches or [ ]) ++ [
              ./patches/systemd-mountpoint-util-chromeos.patch
              ./patches/systemd-process-util-pidfd-fallback.patch
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
            systemd259
            ;
        };
      systemConfigurationOutputs = import ./flake_modules/system-configuration.nix {
        inherit
          self
          nixpkgs
          systemd259
          systemdMinimal259
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
          inherit self nixpkgs board;
        };
      assembleImageOutputs =
        board:
        import ./flake_modules/assemble-image.nix {
          inherit
            self
            nixpkgs
            board
            systemd259
            systemdMinimal259
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
        # Wraps configuration.nix to inject systemd259 and systemdMinimal259 overlay
        # so consumers importing this module don't need to provide them separately
        chromeos = {
          imports = [ ./shimboot_config/base_configuration/configuration.nix ];
          _module.args = {
            inherit systemd259;
            inherit systemdMinimal259;
          };
          # Apply overlay to replace systemdMinimal with 259.5 variant
          # This ensures udevadm verify uses the correct systemd version
          nixpkgs.overlays = [
            (_final: _prev: { systemdMinimal = systemdMinimal259; })
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
