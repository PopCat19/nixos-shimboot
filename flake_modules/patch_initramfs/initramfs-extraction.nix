# initramfs-extraction.nix
#
# Purpose: Extract initramfs from ChromeOS kernel blobs with multi-layer decompression
#
# This module:
# - Extracts vmlinuz from ChromeOS kernel blobs using futility
# - Decompresses multiple compression layers (gzip, xz, lz4, zstd)
# - Outputs initramfs in multiple compressed formats
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
          "extracted-kernel-${board}"
          "initramfs-extraction-${board}"
        ];
    };
  };
  extractedKernel = self.packages.${system}."extracted-kernel-${board}";
in
{
  packages.${system}."initramfs-extraction-${board}" = pkgs.stdenv.mkDerivation {
    name = "initramfs-extraction-${board}";
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
      xxd
    ];

    buildPhase = ''
      set -Eeuo pipefail
      runHook preBuild

      mkdir -p work
      cp ${extractedKernel}/kernel.bin work/kernel.bin

      echo "Extracting vmlinuz from ChromeOS kernel blob..."
      futility vbutil_kernel --get-vmlinuz work/kernel.bin --vmlinuz-out work/vmlinuz

      decompress_layer() {
        local infile="$1"
        local outfile="$2"
        local offset
        set +e
        offset=$(binwalk "$infile" 2>/dev/null | awk '/gzip compressed data|XZ compressed data|LZ4 compressed data|Zstandard compressed data/ {print $1; exit}')
        local binwalk_status=$?
        set -e
        if [ -z "$offset" ] || [ "$binwalk_status" -ne 0 ]; then
          echo "No further compression found in $infile, copying as-is"
          cp "$infile" "$outfile"
          return
        fi
        echo "Found compression at offset $offset in $infile"
        dd if="$infile" of=work/tmp.bin bs=1 skip="$offset" status=none conv=notrunc 2>/dev/null || true
        MAGIC=$(xxd -l 4 -p work/tmp.bin 2>/dev/null || echo "")
        echo "Magic bytes: $MAGIC"
        case "$MAGIC" in
          1f8b*)
            echo "Detected: gzip"
            set +e
            gzip -dc work/tmp.bin > "$outfile" 2>&1
            set -e
            ;;
          fd377a58|fd37*)
            echo "Detected: xz"
            set +e
            xz -dc work/tmp.bin > "$outfile" 2>&1
            set -e
            ;;
          02224b18*)
            echo "Detected: lz4"
            set +e
            lz4 -dc work/tmp.bin "$outfile" 2>&1
            set -e
            ;;
          28b52ffd*)
            echo "Detected: zstd"
            set +e
            zstd -dc work/tmp.bin > "$outfile" 2>&1
            set -e
            ;;
          *)
            echo "Unknown magic: $MAGIC, trying gzip as fallback"
            set +e
            gzip -dc work/tmp.bin > "$outfile" 2>&1
            set -e
            ;;
        esac
        if [ ! -s "$outfile" ]; then
          echo "ERROR: Decompression produced empty file"
          exit 1
        fi
        if [ ! -s "$outfile" ]; then
          echo "ERROR: Decompression produced empty file"
          exit 1
        fi
        ls -la "$outfile" || true
        if [ ! -s "$outfile" ]; then
          echo "WARNING: Decompression produced empty file, copying input"
          cp "$infile" "$outfile"
        fi
      }

      echo "Decompressing first layer from vmlinuz..."
      decompress_layer work/vmlinuz work/decompressed1.bin || true

      echo "Decompressing second layer if present..."
      decompress_layer work/decompressed1.bin work/decompressed2.bin || cp work/decompressed1.bin work/decompressed2.bin || true

      echo "Searching for CPIO archive with retry handling..."
      BINWALK_ATTEMPTS=3
      CPIO_OFFSET=""
      for attempt in $(seq 1 "$BINWALK_ATTEMPTS"); do
        set +e
        CPIO_OFFSET=$(binwalk work/decompressed2.bin 2>&1 | awk '/CPIO ASCII archive/ {print $1; exit}')
        status=$?
        set -e
        if [ "$status" -eq 0 ] && [ -n "$CPIO_OFFSET" ]; then
          echo "Found CPIO archive at offset $CPIO_OFFSET (attempt $attempt)"
          break
        else
          echo "binwalk attempt $attempt/$BINWALK_ATTEMPTS failed (status=$status); retrying..."
          sleep 2
        fi
      done

      if [ -z "$CPIO_OFFSET" ]; then
        echo "ERROR: No CPIO archive found after decompression"
        exit 1
      fi

      dd if=work/decompressed2.bin of=work/initramfs.cpio bs=1 skip="$CPIO_OFFSET" status=none

      mkdir -p work/initramfs
      (cd work/initramfs && cpio -idm --no-absolute-filenames --no-preserve-owner 2>/dev/null < ../initramfs.cpio || true)

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
      maintainers = [ "shimboot developers" ];
    };
  };
}
