# harvest-drivers.nix
#
# Purpose: Extract ChromeOS kernel modules and firmware from shim/recovery images
#
# This module:
# - Extracts rootfs partitions from ChromeOS shim/recovery images (squashfs or ext4)
# - Collects /lib/modules, /lib/firmware, and /etc/modprobe.d
# - Outputs a derivation consumable by repart-based image assembly
# - Uses dd + unsquashfs + debugfs (no loop devices or mount required)
{
  self,
  nixpkgs,
  board ? "dedede",
}:
let
  system = "x86_64-linux";
  pkgs = import nixpkgs {
    inherit system;
    config.allowUnfreePredicate = pkg: builtins.elem (nixpkgs.lib.getName pkg) [
      "harvested-drivers-${board}"
    ];
  };

  shim = self.packages.${system}."chromeos-shim-${board}";
  recovery = self.packages.${system}."chromeos-recovery-${board}";

  # Upstream ChromiumOS linux-firmware for augmentation
  # Uses git fetch (not tarball) since googlesource archive URLs with
  # the +archive path format are broken by fetchTarball's URL encoding.
  # Full clone is large (~3GB) but cached in Nix store after first fetch.
  upstreamFirmware = builtins.fetchGit {
    url = "https://chromium.googlesource.com/chromiumos/third_party/linux-firmware.git";
    ref = "refs/heads/master";
  };
in
{
  packages.${system}."harvested-drivers-${board}" = pkgs.stdenv.mkDerivation {
    name = "harvested-drivers-${board}";

    inherit shim recovery upstreamFirmware;

    dontUnpack = true;
    dontConfigure = true;

    nativeBuildInputs = with pkgs; [
      gptfdisk
      squashfsTools
      e2fsprogs
      coreutils
      gawk
      gnugrep
    ];

      buildPhase = ''
        runHook preBuild

        mkdir -p work harvested

        # Check if an image is ext4 by looking for the superblock magic
        is_ext4() {
          local img="$1"
          local magic
          magic=$(dd if="$img" bs=1 skip=1080 count=2 2>/dev/null | od -An -tx1 | tr -d ' \n')
          [ "$magic" = "53ef" ]
        }

        # Try to extract an ext4 image using debugfs rdump
        extract_ext4() {
          local img="$1"
          local outdir="$2"
          if ! is_ext4 "$img"; then
            return 1
          fi
          echo "  Found ext4 filesystem"
          mkdir -p "$outdir"
          if debugfs -R "rdump / $outdir" "$img" >/dev/null 2>&1; then
            echo "  Extracted to $outdir"
            return 0
          fi
          rm -rf "$outdir" 2>/dev/null || true
          return 1
        }

        # Parse partition start sector from sgdisk -i output
        get_start_sector() {
          local img="$1" pn="$2"
          sgdisk -i "$pn" "$img" 2>/dev/null | grep "First sector" | awk '{print $3}'
        }

        # Parse partition size in sectors from sgdisk -i output
        get_size_sectors() {
          local img="$1" pn="$2"
          sgdisk -i "$pn" "$img" 2>/dev/null | grep "Partition size" | awk '{print $3}'
        }

        # Check partition exists by verifying start sector is non-empty
        partition_exists() {
          local img="$1" pn="$2"
          local s
          s=$(get_start_sector "$img" "$pn")
          [ -n "$s" ]
        }

        harvest_image() {
          local img="$1"
          local label="$2"

          echo "Processing $label: $(basename $img)"

          # Helper: try to extract rootfs from a partition
          try_extract_partition() {
            local pn="$1"
            if ! partition_exists "$img" "$pn"; then
              return 1
            fi
            local start size
            start=$(get_start_sector "$img" "$pn")
            size=$(get_size_sectors "$img" "$pn")
            [ -z "$start" ] && return 1
            [ -z "$size" ] && return 1
            echo "  Partition $pn: start=$start size=$size"
            local loc="''${label}_p$pn"
            dd if="$img" of="work/$loc.img" bs=512 skip="$start" count="$size" status=none 2>/dev/null || return 1
            if unsquashfs -s "work/$loc.img" >/dev/null 2>&1; then
              echo "  Found squashfs in $label partition $pn"
              unsquashfs -d "work/''${label}_rootfs" "work/$loc.img" >/dev/null 2>&1 || true
              if [ -d "work/''${label}_rootfs" ]; then
                echo "  Extracted rootfs from $label partition $pn"
                return 0
              fi
            fi
            if extract_ext4 "work/$loc.img" "work/''${label}_rootfs"; then
              return 0
            fi
            return 1
          }

          # Find rootfs partition (usually the largest squashfs or ext4 partition)
          for pn in 4 5 6 3; do
            if partition_exists "$img" "$pn"; then
              try_extract_partition "$pn" && return 0
            fi
          done

          # Fallback: try extracting all partitions
          local num_parts
          num_parts=$(sgdisk -p "$img" 2>/dev/null | grep -c "^   [0-9]" || echo 0)
          echo "  $label has $num_parts partitions, trying each..."
          for ((i=1; i<=num_parts; i++)); do
            try_extract_partition "$i" && return 0
          done

          echo "  WARNING: No squashfs or ext4 rootfs found in $label"
          return 1
        }

        # Harvest from recovery first (more drivers), then shim
        [ -f "$recovery" ] && harvest_image "$recovery" "recovery" || true
        [ -f "$shim" ] && harvest_image "$shim" "shim" || true

        # Collect drivers from all extracted roots
        for rootdir in work/*_rootfs; do
          [ -d "$rootdir" ] || continue
          echo "Collecting drivers from $rootdir"
          if [ -d "$rootdir/lib/modules" ]; then
            mkdir -p harvested/lib/modules
            cp -a "$rootdir/lib/modules/." harvested/lib/modules/ 2>/dev/null || true
          fi
          if [ -d "$rootdir/lib/firmware" ]; then
            mkdir -p harvested/lib/firmware
            cp -a "$rootdir/lib/firmware/." harvested/lib/firmware/ 2>/dev/null || true
          fi
          if [ -d "$rootdir/etc/modprobe.d" ]; then
            mkdir -p harvested/modprobe.d
            cp -a "$rootdir/etc/modprobe.d/." harvested/modprobe.d/ 2>/dev/null || true
          fi
        done

        MOD_COUNT=$(find harvested/lib/modules -name "*.ko" 2>/dev/null | wc -l || echo 0)
        FW_COUNT=$(find harvested/lib/firmware -type f 2>/dev/null | wc -l || echo 0)
        echo "Harvested: $MOD_COUNT kernel modules, $FW_COUNT firmware files"

        # === Augment with upstream ChromiumOS linux-firmware ===
        if [ -d "$upstreamFirmware" ] && [ "$(ls -A "$upstreamFirmware" 2>/dev/null)" ]; then
          echo "Augmenting firmware with upstream linux-firmware..."
          mkdir -p harvested/lib/firmware
          cp -a "$upstreamFirmware/." harvested/lib/firmware/ 2>/dev/null || true
          FW_AFTER=$(find harvested/lib/firmware -type f 2>/dev/null | wc -l || echo 0)
          echo "Firmware after augmentation: $FW_AFTER files (was $FW_COUNT)"
        else
          echo "Upstream firmware not available, skipping augmentation"
        fi

        # === Prune unused firmware to reduce image size ===
        # Keep only firmware families essential for Chromebook boot, WiFi, and graphics
        echo "Pruning firmware (keeping Chromebook-essential families)..."
        FW_BEFORE=$(find harvested/lib/firmware -type f 2>/dev/null | wc -l || echo 0)
        if [ -d harvested/lib/firmware ] && [ "$FW_BEFORE" -gt 0 ]; then
          find harvested/lib/firmware -type f \
            ! -path "*/intel/*" \
            ! -path "*/iwlwifi/*" \
            ! -path "*/rtw88/*" \
            ! -path "*/rtw89/*" \
            ! -path "*/brcm/*" \
            ! -path "*/ath10k/*" \
            ! -path "*/mediatek/*" \
            ! -name "regulatory.db*" \
            ! -name "*.ucode" \
            -delete 2>/dev/null || true
          find harvested/lib/firmware -type d -empty -delete 2>/dev/null || true
        fi
        FW_AFTER=$(find harvested/lib/firmware -type f 2>/dev/null | wc -l || echo 0)
        echo "Firmware pruned: $FW_BEFORE -> $FW_AFTER files"

        runHook postBuild
      '';

    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      if [ -d harvested/lib ]; then
        cp -a harvested/lib "$out/lib"
      fi
      if [ -d harvested/modprobe.d ]; then
        cp -a harvested/modprobe.d "$out/modprobe.d"
      fi
      # Remove broken symlinks left over from ChromeOS build tree references
      find "$out" -type l -exec sh -c 'test ! -e "$1"' _ {} \; -delete 2>/dev/null || true
      # Metadata
      echo "${board}" > "$out/board.txt"
      MOD_COUNT=$(find "$out/lib/modules" -name "*.ko" 2>/dev/null | wc -l || echo 0)
      echo "$MOD_COUNT" > "$out/module_count.txt"
      runHook postInstall
    '';

    meta = with pkgs.lib; {
      description = "Extracted ChromeOS kernel modules and firmware for ${board}";
      license = licenses.unfree;
      platforms = platforms.linux;
    };
  };
}
