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

      # Systemd 257.x from stable with ChromeOS mount patch
      # Stable's passthru misses some attrs that unstable's systemd module expects
      systemd257 = pkgsStable.systemd.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [
          ./patches/systemd-mountpoint-util-chromeos.patch
        ];
        # Add missing passthru attrs expected by unstable's systemd module
        # Stable exposes: withBootloader, withCryptsetup, withEfi, withFido2, withHostnamed,
        # withImportd, withKmod, withLocaled, withMachined, withNetworkd, withPortabled,
        # withTimedated, withTpm2Tss, withTpm2Units, withUtmp
        # Missing: withNspawn, withLogind, withVconsole, withResolved, withNetworkd already there
        passthru = old.passthru or { } // {
          withNspawn = true;
          withLogind = true;
          withVconsole = true;
        };
        # Stub factory reset units (added in 258, hardcoded in unstable's upstreamSystemUnits)
        postInstall = (old.postInstall or "") + ''
          for unit in factory-reset.target systemd-factory-reset-request.service systemd-factory-reset-reboot.service; do
            printf "[Unit]\nDescription=%s stub (systemd 258+)\n" "$unit" > "$out/example/systemd/system/$unit"
          done
          mkdir -p "$out/example/systemd/system/factory-reset.target.wants"
          # systemd-journalctl added in 258
          printf "[Unit]\nDescription=systemd-journalctl stub\n" > "$out/example/systemd/system/systemd-journalctl.socket"
          printf "[Unit]\nDescription=systemd-journalctl stub\n\n[Service]\nExecStart=/bin/true\n" > "$out/example/systemd/system/systemd-journalctl@.service"
        '';
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
          _module.args.systemd257 = systemd257;
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
