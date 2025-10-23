{
  self,
  nixpkgs,
}: let
  system = "x86_64-linux";
  pkgs = import nixpkgs {
    inherit system;
    config = {
      allowUnfreePredicate = pkg:
        builtins.elem (nixpkgs.lib.getName pkg) [
          "extracted-kernel"
          "initramfs-extraction"
        ];
    };
  };
  extractedKernel = self.packages.${system}.extracted-kernel;
in {
  # Extracted ChromeOS initramfs - derived from proprietary firmware
  # This derivation extracts initramfs from ChromeOS kernel blobs.
  # The output contains proprietary components and remains under unfree license terms.
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

      decompress_layer() {
        local infile="$1"
        local outfile="$2"
        local offset
        offset=$(binwalk "$infile" | awk '/gzip compressed data|XZ compressed data|LZ4 compressed data|Zstandard compressed data/ {print $1; exit}')
        if [ -z "$offset" ]; then
          echo "No further compression found in $infile, copying as-is"
          cp "$infile" "$outfile"
          return
        fi
        echo "Found compression at offset $offset in $infile"
        dd if="$infile" of=work/tmp.bin bs=1 skip="$offset" status=none
        if file work/tmp.bin | grep -q 'gzip compressed'; then
          gzip -dc work/tmp.bin > "$outfile" || true
        elif file work/tmp.bin | grep -q 'XZ compressed'; then
          xz -dc work/tmp.bin > "$outfile" || true
        elif file work/tmp.bin | grep -q 'LZ4'; then
          lz4 -dc work/tmp.bin "$outfile" || true
        elif file work/tmp.bin | grep -q 'Zstandard'; then
          zstd -dc work/tmp.bin > "$outfile" || true
        else
          echo "ERROR: Unknown compression type in $infile"
          exit 1
        fi
        if [ ! -s "$outfile" ]; then
          echo "ERROR: Decompression produced empty file from $infile"
          exit 1
        fi
      }

      echo "Decompressing first layer from vmlinuz..."
      decompress_layer work/vmlinuz work/decompressed1.bin

      echo "Decompressing second layer if present..."
      decompress_layer work/decompressed1.bin work/decompressed2.bin

      echo "Searching for CPIO archive..."
      CPIO_OFFSET=$(binwalk work/decompressed2.bin | awk '/CPIO ASCII archive/ {print $1; exit}')
      if [ -z "$CPIO_OFFSET" ]; then
        echo "ERROR: No CPIO archive found after decompression"
        exit 1
      fi
      echo "Found CPIO archive at offset $CPIO_OFFSET"

      dd if=work/decompressed2.bin of=work/initramfs.cpio bs=1 skip="$CPIO_OFFSET" status=none

      mkdir -p work/initramfs
      # Extract, ignoring mknod errors in sandbox
      (cd work/initramfs && cpio -idm --no-absolute-filenames --no-preserve-owner 2>/dev/null < ../initramfs.cpio || true)

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
      description = "Extract initramfs from ChromeOS kernel blob using futility with multi-layer decompression";
      license = licenses.unfree;
      platforms = platforms.linux;
      maintainers = ["shimboot developers"];
    };
  };
}
