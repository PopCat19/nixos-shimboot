{
  self,
  nixpkgs,
  ...
}: let
  system = "x86_64-linux";
  pkgs = nixpkgs.legacyPackages.${system};
in {
  devShells.${system}.default = pkgs.mkShell {
    buildInputs = with pkgs; [
      # Nix tooling
      nixos-generators
      nixpkgs-fmt
      alejandra # Better formatter

      # Image assembly tools
      parted
      util-linux # losetup, mount, umount, fdisk
      e2fsprogs # mkfs.ext4
      gawk       # required by disk-space check
      coreutils  # df, sed, etc.
      findutils
      shadow     # for 'su' binary if root escalation via su is used
      pv # progress viewer
      zstd # compression
      vboot_reference # cgpt, futility

      # Development utilities
      git
      jq
    ];

    shellHook = ''
      echo "🦊 nixos-shimboot development environment"
      echo "   run 'sudo -i' or 'su -' to enter root shell if needed"
      echo ""
      echo "📦 Tools available:"
      echo "  • nixos-generators    - Generate NixOS images"
      echo "  • cgpt, futility      - ChromeOS GPT utilities"
      echo "  • parted, losetup     - Disk management"
      echo "  • pv, zstd            - Progress & compression"
      echo ""
      echo "🔨 Common commands:"
      echo "  nix build .#raw-rootfs-minimal          # Build minimal rootfs"
      echo "  nix build .#chromeos-shim-dedede        # Build shim"
      echo "  sudo ./assemble-final.sh --board dedede --rootfs minimal"
      echo ""
      echo "✨ Formatting:"
      echo "  nix fmt                # Format all Nix files"
      echo ""
    '';
  };
}
