# development-environment.nix
#
# Purpose: Provide development shell with tools for building and assembling images
#
# This module:
# - Configures devShell with Nix tooling, image assembly tools, and utilities
# - Provides nixos-generators, cgpt, futility, and disk management tools
# - Displays helpful usage information on shell activation
{ nixpkgs, ... }:
let
  system = "x86_64-linux";
  pkgs = nixpkgs.legacyPackages.${system};
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
    ];

    shellHook = ''
      echo "nixos-shimboot development environment"
      echo ""
      echo "Tools available:"
      echo "  - nixos-generators    - Generate NixOS images"
      echo "  - cgpt, futility      - ChromeOS GPT utilities"
      echo "  - parted, losetup     - Disk management"
      echo "  - pv, zstd            - Progress & compression"
      echo "  - gum                 - TUI framework (rescue helper)"
      echo ""
      echo "Common commands:"
      echo "  nix build .#raw-rootfs-minimal          # Build minimal rootfs"
      echo "  nix build .#chromeos-shim-dedede        # Build shim"
      echo "  sudo ./assemble-final.sh --board dedede --rootfs minimal"
      echo ""
      echo "Formatting:"
      echo "  nix fmt                # Format all Nix files"
      echo ""
    '';
  };
}
