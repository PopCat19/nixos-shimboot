# harvest-drivers.nix
#
# Purpose: Extract ChromeOS kernel modules and firmware from shim/recovery images
#
# This module:
# - Extracts squashfs rootfs partitions from ChromeOS shim/recovery images
# - Collects /lib/modules, /lib/firmware, and /etc/modprobe.d
# - Outputs a derivation consumable by repart-based image assembly
# - Uses dd + unsquashfs (no loop devices or mount required)
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
in
{
  packages.${system}."harvested-drivers-${board}" = pkgs.stdenv.mkDerivation {
    name = "harvested-drivers-${board}";

    inherit shim recovery;

    dontUnpack = true;
    dontConfigure = true;

    nativeBuildInputs = with pkgs; [
      gptfdisk
      squashfsTools
      coreutils
      gawk
      gnugrep
    ];

      buildPhase = ''
        runHook preBuild

        mkdir -p work harvested

        harvest_image() {
          local img="$1"
          local label="$2"
          local part_num
          local start size fstype

          echo "Processing $label: $(basename $img)"

          # Find rootfs partition (usually the largest squashfs partition)
          for pn in 4 5 6 3; do
            part_num=$(sgdisk -i "$pn" -p "$img" 2>/dev/null | grep -i "partition" | awk '{print $2}' | tr -d ':' || true)
            if [ -n "$part_num" ] && [ "$part_num" = "$pn" ] 2>/dev/null; then
              start=$(sgdisk -i "$pn" -p "$img" 2>/dev/null | grep "Partition start sector" | awk '{print $4}')
              size=$(sgdisk -i "$pn" -p "$img" 2>/dev/null | grep "Partition size" | awk '{print $4}' | sed 's/sectors//')
              fstype=$(sgdisk -i "$pn" -p "$img" 2>/dev/null | grep "Partition GUID code" | awk '{print $4}')
              [ -z "$start" ] && continue
              echo "  Partition $pn: start=$start size=$size type=$fstype"
              loc="''${label}_p''${pn}"
              dd if="$img" of="work/$loc.img" bs=512 skip="$start" count="$size" status=none 2>/dev/null || continue
              if unsquashfs -s "work/$loc.img" >/dev/null 2>&1; then
                echo "  Found squashfs in $label partition $pn"
                unsquashfs -d "work/''${label}_rootfs" "work/$loc.img" >/dev/null 2>&1 || true
                if [ -d "work/''${label}_rootfs" ]; then
                  echo "  Extracted rootfs from $label partition $pn"
                  return 0
                fi
              fi
            fi
          done

          # Fallback: try extracting all partitions
          local num_parts
          num_parts=$(sgdisk -p "$img" 2>/dev/null | grep -c "^   [0-9]" || echo 0)
          echo "  $label has $num_parts partitions, trying each..."
          for ((i=1; i<=num_parts; i++)); do
            start=$(sgdisk -i "$i" -p "$img" 2>/dev/null | grep "Partition start sector" | awk '{print $4}')
            size=$(sgdisk -i "$i" -p "$img" 2>/dev/null | grep "Partition size" | awk '{print $4}' | sed 's/sectors//')
            [ -z "$start" ] && continue
            loc="''${label}_p$i"
            dd if="$img" of="work/$loc.img" bs=512 skip="$start" count="$size" status=none 2>/dev/null || continue
            if unsquashfs -s "work/$loc.img" >/dev/null 2>&1; then
              echo "  Found squashfs in $label partition $i"
              unsquashfs -d "work/''${label}_rootfs" "work/$loc.img" >/dev/null 2>&1 || true
              if [ -d "work/''${label}_rootfs" ]; then
                echo "  Extracted rootfs from $label partition $i"
                return 0
              fi
            fi
          done

          echo "  WARNING: No squashfs rootfs found in $label"
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
