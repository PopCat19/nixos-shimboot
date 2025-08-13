{ self, nixpkgs, ... }:

let
  system = "x86_64-linux";
  pkgs = nixpkgs.legacyPackages.${system};

  chromeosShim = self.packages.${system}.chromeos-shim;
in {
  packages.${system}.extracted-kernel = pkgs.stdenv.mkDerivation {
    name = "extracted-kernel";
    version = "1.0.0";

    src = chromeosShim;

    nativeBuildInputs = with pkgs; [
      coreutils
      gawk
      gnugrep
      gptfdisk          # sgdisk
      vboot_reference   # cgpt
    ];

    buildPhase = ''
      runHook preBuild

      echo "Starting kernel extraction from ChromeOS shim image (pure file mode)..."

      WORKDIR="$PWD/work"
      mkdir -p "$WORKDIR"

      cp ${chromeosShim}/shim.bin "$WORKDIR/shim.bin"
      echo "Shim image size: $(stat -c%s "$WORKDIR/shim.bin") bytes"

      SECTOR_SIZE=512
      START=""
      SIZE=""

      detect_with_cgpt() {
        if command -v cgpt >/dev/null 2>&1; then
          echo "Using cgpt to locate KERN-A..."
          cgpt show -v "$WORKDIR/shim.bin" | tee "$WORKDIR/partition_info.txt" || true

          PART_NUM=$(cgpt show -v "$WORKDIR/shim.bin" | awk '
            /Sec GPT table/ {next}
            /label: "KERN-A"/ {print n}
            {n=$1}
          ' | head -n1)

          if [ -n "$PART_NUM" ]; then
            START=$(cgpt show -i "$PART_NUM" -b "$WORKDIR/shim.bin" 2>/dev/null || true)
            SIZE=$(cgpt show -i "$PART_NUM" -s "$WORKDIR/shim.bin" 2>/dev/null || true)
            if [ -n "$START" ] && [ -n "$SIZE" ]; then
              echo "Found with cgpt: part=$PART_NUM start=$START size=$SIZE"
              return 0
            fi
          fi

          START=$(cgpt show -i 2 -b "$WORKDIR/shim.bin" 2>/dev/null || true)
          SIZE=$(cgpt show -i 2 -s "$WORKDIR/shim.bin" 2>/dev/null || true)
          if [ -n "$START" ] && [ -n "$SIZE" ]; then
            echo "Falling back to partition 2: start=$START size=$SIZE"
            return 0
          fi
        fi
        return 1
      }

      detect_with_sgdisk() {
        if command -v sgdisk >/dev/null 2>&1; then
          echo "Using sgdisk to locate KERN-A..."
          sgdisk -p "$WORKDIR/shim.bin" | tee "$WORKDIR/partition_info.txt"

          read START END <<<"$(sgdisk -p "$WORKDIR/shim.bin" | awk '
            $1 ~ /^[0-9]+$/ && $NF == "KERN-A" {print $2, $3}
          ' | head -n1)"

          if [ -n "$START" ] && [ -n "$END" ]; then
            SIZE=$((END - START + 1))
            echo "Found with sgdisk: start=$START size=$SIZE"
            return 0
          fi

          read START END <<<"$(sgdisk -p "$WORKDIR/shim.bin" | awk '
            $1 == "2" {print $2, $3}
          ' | head -n1)"
          if [ -n "$START" ] && [ -n "$END" ]; then
            SIZE=$((END - START + 1))
            echo "Falling back to partition 2 via sgdisk: start=$START size=$SIZE"
            return 0
          fi
        fi
        return 1
      }

      if ! detect_with_cgpt; then
        if ! detect_with_sgdisk; then
          echo "ERROR: Could not determine KERN-A start/size"
          exit 1
        fi
      fi

      BYTE_OFFSET=$((START * SECTOR_SIZE))
      BYTE_COUNT=$((SIZE * SECTOR_SIZE))
      echo "Extracting bytes: offset=$BYTE_OFFSET count=$BYTE_COUNT"

      dd if="$WORKDIR/shim.bin" of="$WORKDIR/kernel.bin" bs=$SECTOR_SIZE \
         skip=$START count=$SIZE status=none

      echo "Extracted kernel size: $(stat -c%s "$WORKDIR/kernel.bin") bytes"
      if [ ! -s "$WORKDIR/kernel.bin" ]; then
        echo "ERROR: kernel.bin is empty"
        exit 1
      fi

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      echo "Installing extracted kernel..."
      WORKDIR="$PWD/work"

      mkdir -p "$out"
      cp "$WORKDIR/kernel.bin" "$out/kernel.bin"
      if [ -f "$WORKDIR/partition_info.txt" ]; then
        cp "$WORKDIR/partition_info.txt" "$out/partition_info.txt"
      fi

      echo "Successfully installed extracted kernel ($(stat -c%s "$out/kernel.bin") bytes)"

      runHook postInstall
    '';

    meta = with pkgs.lib; {
      description = "Extracted kernel partition from ChromeOS shim image";
      longDescription = ''
        This derivation extracts the kernel partition (KERN-A) from a ChromeOS
        shim image by parsing the GPT and slicing bytes directly, avoiding any
        need for kernel devices or privileges. The extracted kernel can be used
        for further processing such as initramfs extraction and patching.
      '';
      license = licenses.unfree;
      platforms = platforms.linux;
      maintainers = [ "shimboot developers" ];
    };
  };
}