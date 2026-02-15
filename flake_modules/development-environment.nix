# development-environment.nix
#
# Purpose: Provide development shell with tools for building and assembling images
#
# This module:
# - Configures devShell with Nix tooling, image assembly tools, and utilities
# - Provides nixos-generators, cgpt, futility, and disk management tools
# - Uses fish as the interactive shell with project functions auto-loaded
# - Displays helpful usage information on shell activation
{ nixpkgs, self, ... }:
let
  system = "x86_64-linux";
  pkgs = nixpkgs.legacyPackages.${system};

  # Project fish functions directories
  fishFunctionsDir = "${self}/shimboot_config/base_configuration/system/fish_functions";
  fishHelpersDir = "${self}/shimboot_config/base_configuration/system/helpers";

  # Create a wrapped fish with project functions using wrapFish
  wrappedFish = pkgs.wrapFish {
    # Add project function directories for autoloading
    functionDirs = [
      fishFunctionsDir
      fishHelpersDir
    ];
  };
in
{
  devShells.${system}.default = pkgs.mkShell {
    buildInputs = with pkgs; [
      # Nix tooling
      nixos-generators
      nixpkgs-fmt
      alejandra # Better formatter

      # Image assembly tools
      parted
      util-linux # losetup, mount, etc.
      e2fsprogs # mkfs.ext4, e2fsck
      pv # progress viewer
      zstd # compression
      vboot_reference # cgpt, futility

      # Rescue helper dependencies
      gum # TUI framework for rescue helper

      # Development utilities
      git
      jq

      # Fish shell with project functions
      wrappedFish
    ];

    # Use fish as the interactive shell
    shellHook = ''
      # Display welcome message
      echo "nixos-shimboot development environment"
      echo ""
      echo "Tools available:"
      echo "  - nixos-generators    - Generate NixOS images"
      echo "  - cgpt, futility      - ChromeOS GPT utilities"
      echo "  - parted, losetup     - Disk management"
      echo "  - pv, zstd            - Progress & compression"
      echo "  - gum                 - TUI framework (rescue helper)"
      echo ""
      echo "Fish functions available:"
      echo "  - cnup                - NixOS linting and formatting"
      echo "  - list-fish-helpers   - Show all available helpers"
      echo ""
      echo "Common commands:"
      echo "  nix build .#raw-rootfs-minimal          # Build minimal rootfs"
      echo "  nix build .#chromeos-shim-dedede        # Build shim"
      echo "  sudo ./assemble-final.sh --board dedede --rootfs minimal"
      echo ""
      echo "Formatting:"
      echo "  cnup                  - Lint and format Nix files"
      echo "  nix fmt               # Format all Nix files"
      echo ""

      # Start fish as the interactive shell
      exec fish
    '';
  };
}
