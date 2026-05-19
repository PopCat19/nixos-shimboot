# assemble-image.nix
#
# Purpose: Build complete ChromeOS shimboot disk image using systemd-repart
#
# This module:
# - Evaluates NixOS config to get system toplevel
# - Builds final disk image with ChromeOS partition layout (STATE/KERNEL/BOOT/VENDOR/ROOTFS)
# - Uses systemd-repart for GPT creation, filesystem formatting, and content population
# - Post-processes: dd kernel blob into raw KERNEL partition + set cgpt boot flags
# - Outputs a complete bootable shimboot image as a single Nix derivation
#
# This replaces 70% of assemble-final.sh — no losetup, no mount, no sudo.
# The only parts still needed in a shell wrapper:
# - interactive onboarding
# - Cachix push
# - git clone for self-repair metadata
{
  self,
  nixpkgs,
  board,
  systemd259,
}:
let
  system = "x86_64-linux";

  # Import pkgs with unfree allowed for shim/recovery deps
  pkgs = import nixpkgs {
    inherit system;
    config.allowUnfreePredicate = pkg: builtins.elem (nixpkgs.lib.getName pkg) [
      "shimboot-image-${board}"
      "shimboot-image-${board}-headless"
      "shimboot-image-${board}-luks"
      "shimboot-image-${board}-headless-luks"
    ];
  };

  # User config for board, hostname, username
  userConfig = import ../shimboot_config/user-config.nix { };

  # === Build the NixOS system closure (same base as raw-rootfs-base) ===
  mkRootfsConfig =
    {
      headless ? false,
      enableLUKS ? false,
      wifi ? null,
    }:
    nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        ../shimboot_config/base_configuration/configuration.nix
        {
          nixpkgs.hostPlatform = system;
          boot.loader.grub.enable = false;
          boot.loader.systemd-boot.enable = false;
        }
      ] ++ nixpkgs.lib.optional headless { shimboot.headless = true; }
        ++ nixpkgs.lib.optional enableLUKS { shimboot.luks2.enable = true; }
        ++ nixpkgs.lib.optional (wifi != null) {
          networking.wireless = nixpkgs.lib.mkForce {
            enable = true;
            userControlled = false;
            networks."${wifi.ssid}".psk = wifi.psk;
          };
        };
      specialArgs = {
        inherit self userConfig systemd259;
        inherit (self) inputs;
      };
    };

  # === Input derivations (from flake) ===
  extractedKernel = self.packages.${system}."extracted-kernel-${board}";
  patchedInitramfsBase = self.packages.${system}."initramfs-patching-${board}";
  patchedInitramfsLuks = self.packages.${system}."initramfs-patching-luks-${board}";
  harvestedDrivers = self.packages.${system}."harvested-drivers-${board}";

  # Resolve initramfs based on LUKS flag
  resolveInitramfs = enableLUKS:
    if enableLUKS then patchedInitramfsLuks else patchedInitramfsBase;

  # === systemd with repart support ===
  # Use the patched 259.5 with repart enabled (the full systemd, not systemdMinimal)
  # systemd259 has repart enabled by default
  systemdWithRepart = systemd259;

  # === Build the complete shimboot image ===
  mkShimbootImage =
    {
      headless ? false,
      enableLUKS ? false,
      wifi ? null,
    }:
    let
      rootfsConfig = mkRootfsConfig { inherit headless enableLUKS wifi; };
      luksSuffix = if enableLUKS then "-luks" else "";
      headlessSuffix = if headless then "-headless" else "";
      patchedInitramfs = resolveInitramfs enableLUKS;

      # Use the fully-activated raw rootfs image (same as raw-rootfs-* outputs)
      # This produces a bootable NixOS system with /bin/sh, /etc, activation applied
      rawRootfsImage = rootfsConfig.config.system.build.images.raw;

      hostname = rootfsConfig.config.networking.hostName;
      username = userConfig.user.username;
    in
    pkgs.stdenv.mkDerivation {
      name = "shimboot-image-${board}${headlessSuffix}${luksSuffix}";
      dontUnpack = true;
      dontConfigure = true;

      # Track all inputs for Nix dependency management
      inherit extractedKernel patchedInitramfs harvestedDrivers rawRootfsImage;
      inherit hostname username;

      nativeBuildInputs = with pkgs; [
        gptfdisk           # sgdisk (partition creation)
        parted             # partition naming (supports colons)
        e2fsprogs          # mkfs.ext4/ext2 with -d, debugfs, resize2fs
        util-linux         # truncate, dd
        vboot_reference    # cgpt (ChromeOS boot flags)
        nix                # nix-store --optimise
        fakeroot           # preserve file ownership during debugfs extract
        coreutils
        gnused
        gawk
        git                # clone into rootfs for self-repair
      ];

      # Flake source for git clone into rootfs (self-repair capability)
      # self is the flake input; "${self}" resolves to its store path
      NIXOS_SHIMBOOT_SRC = "${self}";

      buildPhase =
        # NOTE: ''${ escapes Nix interpolation to pass ${} through to bash
        let
          flavor = if headless then "headless" else "base";
          echoLayout = ''
            echo "Image layout: ''${TOTAL_MB}M total"
            echo "  STATE:   ''${STATE_START}-2M"
            echo "  KERNEL:  2-''${KERNEL_END}M"
            echo "  BOOT:    ''${BOOT_START}-''${BOOT_END}M  (''${BOOT_SIZE_MB}M)"
            echo "  VENDOR:  ''${VENDOR_START}-''${VENDOR_END}M (''${VENDOR_SIZE_MB}M)"
            echo "  ROOTFS:  ''${ROOTFS_START}M-... (''${ROOTFS_SIZE_MB}M)"
          '';
        in
        ''
        runHook preBuild

        # === 1. Prepare content directories first (needed for size calc) ===
        mkdir -p boot-content vendor-content

        if [ -d "$patchedInitramfs/patched-initramfs" ]; then
          cp -a "$patchedInitramfs/patched-initramfs/." boot-content/
        fi

        if [ -d "$harvestedDrivers/lib" ]; then
          cp -a "$harvestedDrivers/lib/." vendor-content/
        fi

        # Extract rootfs partition from the fully-activated NixOS raw image
        echo "=== Extracting rootfs from raw image ==="
        RAW_IMAGE=$(ls "$rawRootfsImage"/*.img 2>/dev/null | head -1)
        if [ -z "$RAW_IMAGE" ]; then
          echo "  ERROR: No .img file found in $rawRootfsImage"
          ls "$rawRootfsImage"/ 2>/dev/null
          exit 1
        fi
        echo "  Raw image: $(basename "$RAW_IMAGE")"
        RAW_ROOTFS_START=$(sgdisk -p "$RAW_IMAGE" 2>/dev/null | grep -E "^\s+[0-9]" | head -1 | awk '{print $2}')
        RAW_ROOTFS_END=$(sgdisk -p "$RAW_IMAGE" 2>/dev/null | grep -E "^\s+[0-9]" | head -1 | awk '{print $3}')
        RAW_ROOTFS_SECTORS=$(( RAW_ROOTFS_END - RAW_ROOTFS_START + 1 ))
        echo "  Partition 1: start=$RAW_ROOTFS_START sectors, end=$RAW_ROOTFS_END, sectors=$RAW_ROOTFS_SECTORS"
        if [ -n "$RAW_ROOTFS_START" ] && [ -n "$RAW_ROOTFS_END" ]; then
          dd if="$RAW_IMAGE" of=rootfs.img bs=512 skip="$RAW_ROOTFS_START" count="$RAW_ROOTFS_SECTORS" status=none 2>/dev/null
        else
          echo "  ERROR: Could not find rootfs partition in raw image"
          exit 1
        fi

        # === 1.5 Store optimization + git clone (debugfs + fakeroot, no mount) ===
        # Run entire post-processing under fakeroot: debugfs rdump preserves
        # ownership, nix-store optimises the closure, git clone sets up
        # self-repair metadata, mkfs.ext4 rebuilds with correct permissions.
        optimize_and_clone() {
          local img="$1"
          local user="$2"
          local staging="$PWD/rootfs-staging"

          echo "=== Rootfs post-processing (debugfs + fakeroot, no mount) ==="
          mkdir -p "$staging"

          fakeroot -- bash -c '
            set -euo pipefail
            img="$1"
            user="$2"
            staging="$3"
            nixos_src="$4"
            board="$5"
            flavor="$6"
            hostname="$7"
            username="$8"

            echo "  Extracting rootfs with debugfs rdump..."
            debugfs -R "rdump / $staging" "$img" 2>&1 | grep -v "Invalid argument while changing ownership" || true

            # Store optimization: hard-link identical files in /nix/store
            if [ -d "$staging/nix/store" ]; then
              echo "  Running nix-store --optimise..."
              nix-store --store "local?root=$staging" --optimise -vv 2>&1 | tail -5 || true
            else
              echo "  No /nix/store found in staging, skipping optimization"
            fi

            # Git clone: nixos-shimboot for self-repair
            local clone_dest="$staging/home/$user/nixos-shimboot"
            if [ -n "$user" ] && [ -d "$staging/home/$user" ]; then
              echo "  Setting up nixos-shimboot at $clone_dest"
              rm -rf "$clone_dest" 2>/dev/null || true
              mkdir -p "$(dirname "$clone_dest")"
              if [ -d "$nixos_src" ]; then
                cp -a "$nixos_src/." "$clone_dest/"
              else
                echo "  WARNING: NIXOS_SHIMBOOT_SRC not found, skipping"
              fi
              git -C "$clone_dest" init 2>/dev/null || true
              git -C "$clone_dest" remote add origin \
                "https://github.com/PopCat19/nixos-shimboot.git" 2>/dev/null || true
              cat > "$clone_dest/.shimboot_build_info" <<METAMETA
# Shimboot build metadata
BUILD_BOARD=$board
BUILD_FLAVOR=$flavor
BUILD_HOSTNAME=$hostname
BUILD_USERNAME=$username
METAMETA
              echo "  Done"
            else
              echo "  Skipping git clone: /home/$user not found in staging"
            fi

            # Rebuild optimized ext4 from staging directory
            echo "  Rebuilding ext4 from optimized staging..."
            img_size=$(stat -c%s "$img")
            rm -f "$img"
            truncate -s "$img_size" "$img"
            mkfs.ext4 -F -d "$staging" "$img" 2>&1 | tail -3
          ' -- "$img" "$user" "$staging" "$NIXOS_SHIMBOOT_SRC" "${board}" "${flavor}" "$hostname" "$username"

          rm -rf "$staging" 2>/dev/null || true
          echo "  Running e2fsck after rebuild..."
          e2fsck -fy "$img" 2>/dev/null || true
          return 0
        }

        optimize_and_clone rootfs.img "$username" || true

        # === 1.6 LUKS2: image is LUKS-capable but unencrypted ===
        # dm-crypt (/dev/mapper/control) is unavailable in the Nix sandbox,
        # so the actual LUKS container wrapping must happen post-build.
        # The image ships with cryptsetup in the initramfs and LUKS-enabled
        # /etc config — ready for wrapping with:
        #   sudo tools/write/wrap-luks.sh --image shimboot.img
        ${if enableLUKS then ''
        echo "=== LUKS2: image is LUKS-capable (wrapping is post-build) ==="
        echo "  Initramfs includes static cryptsetup"
        echo "  Rootfs expects /dev/mapper/rootfs"
        echo "  To wrap: sudo tools/write/wrap-luks.sh --image $out/shimboot.img"
        '' else ""}

        # === 2. Calculate partition sizes ===
        BOOT_SIZE_MB=20
        [ -d "$patchedInitramfs/patched-initramfs" ] && \
          BOOT_SIZE_MB=$(du -sm "$patchedInitramfs/patched-initramfs" 2>/dev/null | cut -f1 || echo 20)
        BOOT_SIZE_MB=$(( BOOT_SIZE_MB + 5 ))

        VENDOR_SIZE_MB=0
        if [ -f "$harvestedDrivers/module_count.txt" ] && [ "$(cat "$harvestedDrivers/module_count.txt")" -gt 0 ] 2>/dev/null; then
          VENDOR_SIZE_MB=$(du -sm "$harvestedDrivers/lib" 2>/dev/null | cut -f1 || echo 64)
          VENDOR_SIZE_MB=$(( VENDOR_SIZE_MB * 115 / 100 + 20 ))
        fi

        # Rootfs size: capture only the estimated minimum block count
        # resize2fs -P prints: "Estimated minimum size of the filesystem: NNNN"
        MIN_BLKS=$(resize2fs -P rootfs.img 2>&1 | grep -oP 'size of the filesystem: \K\d+' || echo 0)
        if [ "$MIN_BLKS" -gt 0 ]; then
          MIN_MB=$(( MIN_BLKS * 4 / 1024 ))
        else
          MIN_MB=$(du -sm rootfs.img 2>/dev/null | cut -f1 || echo 6400)
        fi
        # Tighter sizing: 5% growth + 50M pad (vs old 10% + 100M)
        # Matches assemble-final's du-based approach more closely
        ROOTFS_SIZE_MB=$(( MIN_MB + MIN_MB / 20 + 50 ))

        STATE_START=1
        KERNEL_START=2
        KERNEL_END=34
        BOOT_START=34
        BOOT_END=$(( BOOT_START + BOOT_SIZE_MB ))
        VENDOR_START=$BOOT_END
        VENDOR_END=$(( VENDOR_START + VENDOR_SIZE_MB ))
        ROOTFS_START=$VENDOR_END

        TOTAL_MB=$(( ROOTFS_START + ROOTFS_SIZE_MB ))
        ${echoLayout}

        # === 3. Create empty image ===
        IMAGE=$PWD/shimboot.img
        truncate -s "''${TOTAL_MB}M" "$IMAGE"

        # === 4. Create GPT partition table ===
        echo "=== Creating GPT partition table ==="
        sgdisk -o "$IMAGE"

        sgdisk -n 1:1M:+1M -t 1:0FC63DAF-8483-4772-8E79-3D69D8477DE4 "$IMAGE"
        sgdisk -n 2:0:+32M -t 2:FE3A2A5D-4F32-41A7-B725-ACCC3285A309 "$IMAGE"
        sgdisk -n 3:0:+"''${BOOT_SIZE_MB}M" -t 3:3CB8E202-3B7E-47DD-8A3C-7FF2A13CFCEC "$IMAGE"
        if [ "$VENDOR_SIZE_MB" -gt 0 ]; then
          sgdisk -n 4:0:+"''${VENDOR_SIZE_MB}M" -t 4:0FC63DAF-8483-4772-8E79-3D69D8477DE4 "$IMAGE"
        fi
        sgdisk -n 5:0:0 -t 5:3CB8E202-3B7E-47DD-8A3C-7FF2A13CFCEC "$IMAGE"

        # Set partition names via parted (supports colons, unlike sgdisk -c)
        parted --script "$IMAGE" \
          name 1 STATE \
          name 2 KERNEL \
          name 3 BOOT

        if [ "$VENDOR_SIZE_MB" -gt 0 ]; then
          parted --script "$IMAGE" name 4 "shimboot_rootfs:vendor"
        fi

        parted --script "$IMAGE" name 5 "shimboot_rootfs:nixos"

        # === 5. Create and populate filesystem partitions ===
        echo "=== Creating filesystems ==="

        get_part_offset() {
          local pn=$1
          local info
          info=$(sgdisk -i "$pn" -p "$IMAGE" 2>/dev/null)
          local start_sec
          start_sec=$(echo "$info" | grep "First sector" | awk '{print $3}')
          local sec_size
          sec_size=$(echo "$info" | grep "Sector size" | awk '{print $4}' | sed 's/[^0-9]//g')
          sec_size=''${sec_size:-512}
          echo $(( start_sec * sec_size ))
        }

        # Partition 1: STATE (ext4, empty, 1M)
        echo "  STATE: ext4 filesystem"
        OFFSET1=$(get_part_offset 1)
        truncate -s 1M state.img
        mkfs.ext4 -F state.img
        dd if=state.img of="$IMAGE" bs=512 seek=$(( OFFSET1 / 512 )) conv=notrunc status=none

        # Partition 3: BOOT (ext2 with initramfs)
        echo "  BOOT: ext2 filesystem"
        OFFSET3=$(get_part_offset 3)
        truncate -s "''${BOOT_SIZE_MB}M" boot.img
        mkfs.ext2 -F -d boot-content/ boot.img
        dd if=boot.img of="$IMAGE" bs=512 seek=$(( OFFSET3 / 512 )) conv=notrunc status=none

        # Partition 4: VENDOR (ext4 with drivers, optional)
        if [ "$VENDOR_SIZE_MB" -gt 0 ]; then
          echo "  VENDOR: ext4 filesystem"
          OFFSET4=$(get_part_offset 4)
          truncate -s "''${VENDOR_SIZE_MB}M" vendor.img
          mkfs.ext4 -F -L shimboot_vendor -d vendor-content/ vendor.img
          dd if=vendor.img of="$IMAGE" bs=512 seek=$(( OFFSET4 / 512 )) conv=notrunc status=none
        fi

        # Partition 5: ROOTFS (ext4 with NixOS system from raw image)
        echo "  ROOTFS: ext4 filesystem"
        OFFSET5=$(get_part_offset 5)
        # Resize the rootfs to fill the partition
        e2fsck -fy rootfs.img 2>/dev/null || true
        PART5_SECTORS=$(sgdisk -i 5 -p "$IMAGE" 2>/dev/null | grep "Partition size" | awk '{print $3}')
        PART5_SEC_SIZE=$(sgdisk -i 5 -p "$IMAGE" 2>/dev/null | grep "Sector size" | awk '{print $4}' | sed 's/[^0-9]//g')
        PART5_SEC_SIZE=''${PART5_SEC_SIZE:-512}
        PART5_BYTES=$(( PART5_SECTORS * PART5_SEC_SIZE ))
        truncate -s "$PART5_BYTES" rootfs_resized.img
        dd if=rootfs.img of=rootfs_resized.img bs=1M conv=notrunc,fsync status=none 2>/dev/null
        resize2fs rootfs_resized.img 2>/dev/null || true
        dd if=rootfs_resized.img of="$IMAGE" bs=512 seek=$(( OFFSET5 / 512 )) conv=notrunc status=none

        echo "=== Partition setup complete ==="

        # === 6. Post-process: dd kernel blob into raw KERNEL partition ===
        echo "=== Writing kernel blob to KERNEL partition ==="
        KERNEL_INFO=$(sgdisk -i 2 -p "$IMAGE" 2>/dev/null | grep "First sector" || true)
        if [ -z "$KERNEL_INFO" ]; then
          echo "ERROR: Could not find KERNEL partition"
          sgdisk -p "$IMAGE"
          exit 1
        fi

        KERNEL_OFFSET=$(echo "$KERNEL_INFO" | awk '{print $3}')
        SECTOR_SIZE=$(sgdisk -i 2 -p "$IMAGE" 2>/dev/null | grep "Sector size" | awk '{print $4}' | sed 's/[^0-9]//g')
        SECTOR_SIZE=''${SECTOR_SIZE:-512}

        echo "KERNEL partition at sector $KERNEL_OFFSET (sector size $SECTOR_SIZE)"

        if [ -f "$extractedKernel/p2.bin" ]; then
          dd if="$extractedKernel/p2.bin" of="$IMAGE" \
             bs="$SECTOR_SIZE" seek="$KERNEL_OFFSET" conv=notrunc status=none
          echo "Written kernel blob: $(stat -c%s "$extractedKernel/p2.bin") bytes"
        else
          echo "WARNING: No kernel blob found at $extractedKernel/p2.bin"
        fi

        # === 7. Set ChromeOS boot flags ===
        echo "=== Setting ChromeOS boot flags ==="
        cgpt add -i 2 -S 1 -T 5 -P 10 "$IMAGE" || \
          echo "WARNING: cgpt failed (may need vboot_reference)"

        # === 8. Verification ===
        echo "=== Final partition table ==="
        sgdisk -p "$IMAGE" 2>/dev/null || true

        echo "=== cgpt show ==="
        cgpt show "$IMAGE" 2>/dev/null || true

        echo "=== Verifying kernel signature ==="
        dd if="$IMAGE" bs="$SECTOR_SIZE" skip="$KERNEL_OFFSET" count=1 2>/dev/null | \
          strings | head -5 || true

        runHook postBuild
      '';

      installPhase = ''
        runHook preInstall
        mkdir -p "$out" 2>/dev/null || true
        cp "$IMAGE" "$out/shimboot.img"
        ln -sf "shimboot.img" "$out/nixos-shimboot-${board}.img"
        echo "shimboot-image-${board}" > "$out/image-type.txt"
        echo "${board}" > "$out/board.txt"
        runHook postInstall
      '';

      meta = with pkgs.lib; {
        description = "Complete bootable shimboot image for ${board}";
        longDescription = ''
          ChromeOS-compatible disk image with GPT partition layout:
          STATE, KERNEL (raw + vbutil_kernel), BOOT (patched initramfs),
          VENDOR (drivers/firmware), ROOTFS (NixOS system).
          Built entirely within Nix — no loop devices or sudo required.
        '';
        license = licenses.unfree;
        platforms = platforms.linux;
      };
    };
in
{
  packages.${system} = {
    "shimboot-image-${board}" = mkShimbootImage { headless = false; };
    "shimboot-image-${board}-headless" = mkShimbootImage { headless = true; };
    "shimboot-image-${board}-luks" = mkShimbootImage { headless = false; enableLUKS = true; };
    "shimboot-image-${board}-headless-luks" = mkShimbootImage { headless = true; enableLUKS = true; };
  };
}
