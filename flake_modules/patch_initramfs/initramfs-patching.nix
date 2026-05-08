# initramfs-patching.nix
#
# Purpose: Overlay custom bootloader files onto extracted ChromeOS initramfs
#
# This module:
# - Takes extracted initramfs and replaces init with custom bootloader
# - Overlays bootloader directory contents into initramfs
# - Outputs patched initramfs directory and tar archive
# - Optional: bundles static cryptsetup for LUKS2 encrypted rootfs boot
{
  self,
  nixpkgs,
  board ? "dedede",
}:
let
  system = "x86_64-linux";
  pkgs = import nixpkgs {
    inherit system;
    config = {
      allowUnfreePredicate =
        pkg:
        builtins.elem (nixpkgs.lib.getName pkg) [
          "initramfs-extraction-${board}"
          "initramfs-patching-${board}"
          "initramfs-patching-luks-${board}"
        ];
    };
  };

  extractedInitramfs = self.packages.${system}."initramfs-extraction-${board}";
  bootloaderDir = ./../../bootloader;
  extractedKernel = self.packages.${system}."extracted-kernel-${board}";

  # Static cryptsetup for initramfs (~7.6MiB uncompressed, ~2-3MiB compressed)
  cryptsetupStatic = pkgs.pkgsStatic.cryptsetup;

  # Shared derivation builder for initramfs patching
  mkInitramfsPatching =
    {
      withCryptsetup ? false,
    }:
    pkgs.stdenv.mkDerivation {
      name = if withCryptsetup then "initramfs-patching-luks-${board}" else "initramfs-patching-${board}";
      src = extractedInitramfs;

      nativeBuildInputs = with pkgs; [
        coreutils
        findutils
        cpio
        gzip
        xz
        zstd
        lz4
      ];

      buildPhase = ''
        set -euo pipefail
        runHook preBuild

        mkdir -p work
        echo "Unpacking initramfs.tar from extracted initramfs into work/ ..."
        tar --no-same-owner -xf "$src/initramfs.tar" -C work

        echo "Fixing permissions for Nix builder ..."
        chmod -R u+w work/

        echo "Removing original init from initramfs ..."
        rm -f work/init

        echo "Overlaying bootloader files into initramfs ..."
        cp -a ${bootloaderDir}/* work/ || true

        echo "Fixing permissions after overlay ..."
        chmod -R u+w work/

        ${pkgs.lib.optionalString withCryptsetup ''
          echo "Injecting static cryptsetup for LUKS2 boot ..."
          install -Dm755 ${cryptsetupStatic}/bin/cryptsetup work/bin/cryptsetup
        ''}

        echo "Ensuring files in bin/ are executable if present ..."
        if [ -d work/bin ]; then
          chmod +x work/bin/* || true
        fi

        runHook postBuild
      '';

      installPhase = ''
        runHook preInstall
        mkdir -p "$out"

        cp ${extractedKernel}/kernel.bin "$out/original-kernel.bin" || true

        mkdir -p "$out/patched-initramfs"
        cp -a work/* "$out/patched-initramfs/"

        (cd "$out/patched-initramfs" && tar -cf "$out/initramfs.tar" .)

        runHook postInstall
      '';

      meta = with pkgs.lib; {
        description =
          if withCryptsetup then
            "Patch ChromeOS initramfs with custom bootloader and LUKS support"
          else
            "Patch ChromeOS initramfs with custom bootloader files";
        license = licenses.unfree;
        platforms = platforms.linux;
        maintainers = [ "shimboot developers" ];
      };
    };
in
{
  packages.${system} = {
    "initramfs-patching-${board}" = mkInitramfsPatching { withCryptsetup = false; };
    "initramfs-patching-luks-${board}" = mkInitramfsPatching { withCryptsetup = true; };
  };
}
