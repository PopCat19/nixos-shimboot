{
  self,
  nixpkgs,
}: let
  system = "x86_64-linux";
  pkgs = nixpkgs.legacyPackages.${system};

  # Input: extracted initramfs from Step 2
  extractedInitramfs = self.packages.${system}.initramfs-extraction;

  # Path to your bootloader overlay in the repo
  bootloaderDir = ./../../bootloader;
  extractedKernel = self.packages.${system}.extracted-kernel;
in {
  packages.${system}.initramfs-patching = pkgs.stdenv.mkDerivation {
    name = "initramfs-patching";
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
      tar -xf "$src/initramfs.tar" -C work

      echo "Removing original init from initramfs ..."
      rm -f work/init

      echo "Overlaying bootloader files into initramfs ..."
      cp -a ${bootloaderDir}/* work/ || true

      echo "Ensuring files in bin/ are executable if present ..."
      if [ -d work/bin ]; then
        chmod +x work/bin/* || true
      fi

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p "$out"

      # Convenience passthrough of original kernel blob
      cp ${extractedKernel}/kernel.bin "$out/original-kernel.bin" || true

      # Output patched initramfs as a directory and as a tar
      mkdir -p "$out/patched-initramfs"
      cp -a work/* "$out/patched-initramfs/"

      (cd "$out/patched-initramfs" && tar -cf "$out/initramfs.tar" .)

      runHook postInstall
    '';

    meta = with pkgs.lib; {
      description = "Patch ChromeOS initramfs with custom bootloader files";
      license = licenses.unfree;
      platforms = platforms.linux;
      maintainers = ["shimboot developers"];
    };
  };
}
