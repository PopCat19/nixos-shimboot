{
  self,
  nixpkgs,
  ...
}: let
  system = "x86_64-linux";
  pkgs = import nixpkgs {
    inherit system;
    config = {
      allowUnfreePredicate = pkg:
        builtins.elem (nixpkgs.lib.getName pkg) [
          "chromeos-shim"
          "extracted-kernel"
        ];
    };
  };

  chromeosShim = self.packages.${system}.chromeos-shim;
in {
  # Extracted ChromeOS kernel - derived from proprietary firmware
  # This derivation extracts kernel blobs from ChromeOS shim firmware.
  # The output contains proprietary code and remains under unfree license terms.
  packages.${system}.extracted-kernel = pkgs.stdenv.mkDerivation {
    name = "extracted-kernel";
    version = "1.1.0";

    src = chromeosShim;
    unpackPhase = "true";

    nativeBuildInputs = with pkgs; [
      coreutils
      gawk
      gnugrep
      gptfdisk # sgdisk
      vboot_reference # cgpt, vbutil_kernel
    ];

    buildPhase = ''
      set -euo pipefail
      runHook preBuild

      echo "Extracting KERN-A from ChromeOS shim image..."

      WORKDIR="$PWD/work"
      mkdir -p "$WORKDIR"

      cp "$src" "$WORKDIR/shim.bin"

      # --- Step 1: Locate KERN-A partition ---
      echo "Locating KERN-A partition..."
      START=""
      SIZE=""
      SECTOR_SIZE=512

      if command -v cgpt >/dev/null 2>&1; then
        START=$(cgpt show -i 2 -b "$WORKDIR/shim.bin" 2>/dev/null || true)
        SIZE=$(cgpt show -i 2 -s "$WORKDIR/shim.bin" 2>/dev/null || true)
      fi

      if [ -z "$START" ] || [ -z "$SIZE" ]; then
        echo "Falling back to sgdisk..."
        read START END <<<"$(sgdisk -p "$WORKDIR/shim.bin" | awk '$1 == "2" {print $2, $3}')"
        SIZE=$((END - START + 1))
      fi

      if [ -z "$START" ] || [ -z "$SIZE" ]; then
        echo "ERROR: Could not locate KERN-A partition"
        exit 1
      fi

      echo "KERN-A start sector: $START, size: $SIZE sectors"

      # --- Step 2: Extract raw p2 ---
      dd if="$WORKDIR/shim.bin" of="$WORKDIR/p2.bin" \
         bs=$SECTOR_SIZE skip=$START count=$SIZE status=none

      # --- Step 3: Search for CHROMEOS magic ---
      echo "Searching for CHROMEOS magic..."
      MAGIC_OFFSET=$(grep -aob 'CHROMEOS' "$WORKDIR/p2.bin" | head -n1 | cut -d: -f1 || true)

      if [ -z "$MAGIC_OFFSET" ]; then
        echo "ERROR: Could not find CHROMEOS magic in KERN-A"
        exit 1
      fi

      echo "Found CHROMEOS magic at byte offset $MAGIC_OFFSET inside p2"

      # --- Step 4: Carve inner kernel blob ---
      dd if="$WORKDIR/p2.bin" of="$WORKDIR/kernel.bin" \
         bs=1 skip=$MAGIC_OFFSET status=none

      echo "Extracted kernel blob size: $(stat -c%s "$WORKDIR/kernel.bin") bytes"

      # --- Step 5: Verify with vbutil_kernel ---
      if ! vbutil_kernel --verify "$WORKDIR/kernel.bin" --verbose; then
        echo "WARNING: vbutil_kernel verify failed (expected if patched)"
      fi

      # Save offset for repacking later
      echo "$MAGIC_OFFSET" > "$WORKDIR/kernel_offset.txt"

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      cp "$WORKDIR/kernel.bin" "$out/kernel.bin"
      cp "$WORKDIR/kernel_offset.txt" "$out/kernel_offset.txt"
      cp "$WORKDIR/p2.bin" "$out/p2.bin"
      runHook postInstall
    '';

    meta = with pkgs.lib; {
      description = "Extract ChromeOS kernel blob from shim image, handling wrapped formats";
      longDescription = ''
        This derivation extracts the actual ChromeOS vbutil_kernel blob from
        the KERN-A partition of a shim image. It supports both legacy shims
        (CHROMEOS magic at offset 0) and new RMA shims where the blob is
        wrapped inside another binary.
      '';
      license = licenses.unfree;
      platforms = platforms.linux;
      maintainers = ["shimboot developers"];
    };
  };
}
