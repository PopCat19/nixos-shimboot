{ self, nixpkgs }:

let
  system = "x86_64-linux";
  pkgs = nixpkgs.legacyPackages.${system};

  # Input: extracted initramfs from Step 2
  extractedInitramfs = self.packages.${system}.initramfs-extraction;

  # Path to your bootloader overlay in the repo
  bootloaderDir = ./../../bootloader;
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
      echo "Unpacking initramfs.tar from extracted initramfs..."
      tar -xf $src/initramfs.tar -C work

      echo "Removing original init..."
      rm -f work/init

      echo "Copying bootloader overlay..."
      cp -a ${bootloaderDir}/* work/

      echo "Making all files in bin/ executable..."
      if [ -d work/bin ]; then
        chmod +x work/bin/* || true
      fi

      echo "Repacking initramfs..."
      mkdir -p repack
      (cd work && find . -print0 | LC_ALL=C sort -z | \
        cpio --null -ov --format=newc 2>/dev/null > ../repack/initramfs.cpio)

      gzip -c -9 repack/initramfs.cpio > repack/initramfs.cpio.gz
      xz -c -9e repack/initramfs.cpio > repack/initramfs.cpio.xz
      zstd -q -19 -f repack/initramfs.cpio -o repack/initramfs.cpio.zst
      lz4 -q -9 repack/initramfs.cpio repack/initramfs.cpio.lz4

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p "$out"

      cp repack/initramfs.cpio "$out/initramfs.cpio"
      cp repack/initramfs.cpio.gz "$out/initramfs.cpio.gz"
      cp repack/initramfs.cpio.xz "$out/initramfs.cpio.xz"
      cp repack/initramfs.cpio.zst "$out/initramfs.cpio.zst"
      cp repack/initramfs.cpio.lz4 "$out/initramfs.cpio.lz4"

      runHook postInstall
    '';

    meta = with pkgs.lib; {
      description = "Patch ChromeOS initramfs with custom bootloader files";
      license = licenses.unfree;
      platforms = platforms.linux;
      maintainers = [ "shimboot developers" ];
    };
  };
}