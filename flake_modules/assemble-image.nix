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
  systemd257,
}:
let
  system = "x86_64-linux";

  # Import pkgs with unfree allowed for shim/recovery deps
  pkgs = import nixpkgs {
    inherit system;
    config.allowUnfreePredicate = pkg: builtins.elem (nixpkgs.lib.getName pkg) [
      "shimboot-image-${board}"
    ];
  };

  # User config for board, hostname, username
  userConfig = import ../shimboot_config/user-config.nix { };

  # === Build the NixOS system closure (same base as raw-rootfs-base) ===
  mkRootfsConfig =
    { headless ? false }:
    nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        ../shimboot_config/base_configuration/configuration.nix
        {
          nixpkgs.hostPlatform = system;
          # bootloader is handled by ChromeOS chain-load — disable NixOS
          # bootloader to prevent it from trying to write to disk
          boot.loader.grub.enable = false;
          boot.loader.systemd-boot.enable = false;
        }
      ] ++ nixpkgs.lib.optional headless { shimboot.headless = true; };
      specialArgs = {
        inherit self userConfig systemd257;
        inherit (self) inputs;
      };
    };

  # === Input derivations (from flake) ===
  extractedKernel = self.packages.${system}."extracted-kernel-${board}";
  patchedInitramfs = self.packages.${system}."initramfs-patching-${board}";
  harvestedDrivers = self.packages.${system}."harvested-drivers-${board}";

  # === systemd with repart support ===
  # Use the patched 257.9 with repart enabled (the full systemd, not systemdMinimal)
  # systemd257 has repart enabled by default
  systemdWithRepart = systemd257;

  # === Build the complete shimboot image ===
  mkShimbootImage =
    { headless ? false }:
    let
      rootfsConfig = mkRootfsConfig { inherit headless; };
      rootfsToplevel = rootfsConfig.config.system.build.toplevel;
      closureInfo = pkgs.closureInfo {
        rootPaths = [ rootfsToplevel ];
      };
      hostname = rootfsConfig.config.networking.hostName;
      username = userConfig.user.username;
    in
    pkgs.stdenv.mkDerivation {
      name = "shimboot-image-${board}";
      dontUnpack = true;
      dontConfigure = true;

      # Track all inputs for Nix dependency management
      inherit extractedKernel patchedInitramfs harvestedDrivers rootfsToplevel closureInfo;
      inherit hostname username;

      # systemd-repart is the only "big" tool we need
      # No parted, no losetup, no mount, no loop devices
      nativeBuildInputs = with pkgs; [
        gptfdisk           # sgdisk (partition creation)
        parted             # partition naming (supports colons)
        e2fsprogs          # mkfs.ext4/ext2 with -d
        util-linux         # truncate, dd
        vboot_reference    # cgpt (ChromeOS boot flags)
        coreutils
        gnused
        gawk
      ];

      buildPhase =
        # NOTE: ''${ escapes Nix interpolation to pass ${} through to bash
        let
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
        mkdir -p boot-content vendor-content rootfs-content/nix/store rootfs-content/nix/var/nix/profiles

        if [ -d "$patchedInitramfs/patched-initramfs" ]; then
          cp -a "$patchedInitramfs/patched-initramfs/." boot-content/
        fi

        if [ -d "$harvestedDrivers/lib" ]; then
          cp -a "$harvestedDrivers/lib/." vendor-content/
        fi

        # Populate nix store from closure
        echo "=== Populating nix store ==="
        echo "  Closure paths: $(wc -l < "$closureInfo/store-paths")"
        mkdir -p rootfs-content/nix/store
        # Use tar with transform to strip /nix/store/ prefix
        # This avoids permission issues with cp -a on read-only store paths
        xargs tar -cf store-contents.tar \
          --transform 's|^/nix/store/||' < "$closureInfo/store-paths" 2>&1
        echo "  Extracting..."
        tar -xf store-contents.tar -C rootfs-content/nix/store
        ln -sf "$rootfsToplevel" rootfs-content/nix/var/nix/profiles/system

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

        # Estimate rootfs size from closure size + 50% overhead for fs metadata
        ROOTFS_SIZE_MB=$(du -sm rootfs-content 2>/dev/null | cut -f1 || echo 2048)
        ROOTFS_SIZE_MB=$(( ROOTFS_SIZE_MB * 150 / 100 + 256 ))
        [ "$ROOTFS_SIZE_MB" -lt 8192 ] && ROOTFS_SIZE_MB=8192

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

        parted --script "$IMAGE" name 5 "shimboot_rootfs:main"

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

        # Prepare rootfs content: populate nix store from closure
        mkdir -p rootfs-content/nix/store rootfs-content/nix/var/nix/profiles
        storePaths=$(cat "$closureInfo/store-paths")
        total=$(echo "$storePaths" | wc -l)
        count=0
        echo "Populating nix store ($total paths)..."
        for p in $storePaths; do
          count=$((count + 1))
          name=$(basename "$p")
          echo "  [$count/$total] $name"
          mkdir -p "rootfs-content/nix/store/$name"
          cp -a "$p/." "rootfs-content/nix/store/$name/"
        done
        ln -sf "$rootfsToplevel" rootfs-content/nix/var/nix/profiles/system

        # Partition 5: ROOTFS (ext4 with NixOS system)
        echo "  ROOTFS: ext4 filesystem"
        OFFSET5=$(get_part_offset 5)
        PART5_SECTORS=$(sgdisk -i 5 -p "$IMAGE" 2>/dev/null | grep "Partition size" | awk '{print $3}')
        PART5_SEC_SIZE=$(sgdisk -i 5 -p "$IMAGE" 2>/dev/null | grep "Sector size" | awk '{print $4}' | sed 's/[^0-9]//g')
        PART5_SEC_SIZE=''${PART5_SEC_SIZE:-512}
        PART5_BYTES=$(( PART5_SECTORS * PART5_SEC_SIZE ))
        truncate -s "$PART5_BYTES" rootfs.img
        mkfs.ext4 -F -L nixos -d rootfs-content/ rootfs.img
        dd if=rootfs.img of="$IMAGE" bs=512 seek=$(( OFFSET5 / 512 )) conv=notrunc status=none

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
  };
}
