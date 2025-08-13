{ self, nixpkgs }:

let
  system = "x86_64-linux";
  pkgs = nixpkgs.legacyPackages.${system};
  extractedKernel = self.packages.${system}.extracted-kernel;
in {
  packages.${system}.initramfs-extraction = pkgs.stdenv.mkDerivation {
    name = "initramfs-extraction";
    src = extractedKernel;

    nativeBuildInputs = with pkgs; [
      coreutils
      findutils
      gawk
      gnugrep
      binwalk
      cpio
      lz4
      xz
      zstd
      vboot_reference # futility/vbutil_kernel
    ];

    buildPhase = ''
      set -euo pipefail
      runHook preBuild

      mkdir -p work
      cp ${extractedKernel}/kernel.bin work/kernel.bin

      echo "Extracting vmlinuz from ChromeOS kernel blob..."
      futility vbutil_kernel --get-vmlinuz work/kernel.bin --vmlinuz-out work/vmlinuz

      echo "Searching for compressed payload inside vmlinuz..."
      COMP_OFFSET=$(binwalk work/vmlinuz | awk '/gzip compressed data|XZ compressed data|LZ4 compressed data|Zstandard compressed data/ {print $1; exit}')
      if [ -z "$COMP_OFFSET" ]; then
        echo "ERROR: No known compressed payload found in vmlinuz"
        exit 1
      fi
      echo "Found compressed payload at offset $COMP_OFFSET"

      dd if=work/vmlinuz of=work/payload.bin bs=1 skip=$COMP_OFFSET status=none

      # Detect compression type and decompress
      if file work/payload.bin | grep -q 'gzip compressed'; then
        gzip -dc work/payload.bin > work/decompressed.bin
      elif file work/payload.bin | grep -q 'XZ compressed'; then
        xz -dc work/payload.bin > work/decompressed.bin
      elif file work/payload.bin | grep -q 'LZ4'; then
        lz4 -dc work/payload.bin work/decompressed.bin
      elif file work/payload.bin | grep -q 'Zstandard'; then
        zstd -dc work/payload.bin > work/decompressed.bin
      else
        echo "ERROR: Unknown compression type in payload"
        exit 1
      fi

      # Now find CPIO inside decompressed.bin
      CPIO_OFFSET=$(binwalk work/decompressed.bin | awk '/CPIO ASCII archive/ {print $1; exit}')
      if [ -z "$CPIO_OFFSET" ]; then
        echo "ERROR: No CPIO archive found after decompression"
        exit 1
      fi
      echo "Found CPIO archive at offset $CPIO_OFFSET"

      dd if=work/decompressed.bin of=work/initramfs.cpio bs=1 skip=$CPIO_OFFSET status=none

      mkdir -p work/initramfs
      (cd work/initramfs && cpio -idm --no-absolute-filenames < ../initramfs.cpio)

      # Produce compressed variants
      gzip -c -9 work/initramfs.cpio > work/initramfs.cpio.gz
      xz -c -9e work/initramfs.cpio > work/initramfs.cpio.xz
      zstd -q -19 work/initramfs.cpio -o work/initramfs.cpio.zst
      lz4 -q -9 work/initramfs.cpio work/initramfs.cpio.lz4

      runHook postBuild
    '';

    installPhase = ''
      set -euo pipefail
      runHook preInstall
      mkdir -p "$out"

      cp work/kernel.bin "$out/kernel.bin"
      cp work/vmlinuz "$out/vmlinuz"
      (cd work/initramfs && tar -cf "$out/initramfs.tar" .)
      cp work/initramfs.cpio "$out/initramfs.cpio"
      cp work/initramfs.cpio.gz "$out/initramfs.cpio.gz"
      cp work/initramfs.cpio.xz "$out/initramfs.cpio.xz"
      cp work/initramfs.cpio.zst "$out/initramfs.cpio.zst"
      cp work/initramfs.cpio.lz4 "$out/initramfs.cpio.lz4"

      runHook postInstall
    '';

    meta = with pkgs.lib; {
      description = "Extract initramfs from ChromeOS kernel blob using futility";
      license = licenses.unfree;
      platforms = platforms.linux;
      maintainers = [ "shimboot developers" ];
    };
  };
}