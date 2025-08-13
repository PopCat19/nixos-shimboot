{ self, nixpkgs }:

let
  system = "x86_64-linux";
  pkgs = nixpkgs.legacyPackages.${system};

  # Inputs from previous steps
  patchedKernel = self.packages.${system}.kernel-repack;
  bootloaderDir = ./../../bootloader;
  rootfsImage   = self.packages.${system}.raw-rootfs; # raw-rootfs derivation
in {
  packages.${system}.final-image = pkgs.stdenv.mkDerivation {
    name = "shimboot-final-image";
    src = null;
    unpackPhase = "true";

    nativeBuildInputs = with pkgs; [
      coreutils
      e2fsprogs
      dosfstools
      util-linux
      parted
      pv
    ];

    buildPhase = ''
      set -euo pipefail
      runHook preBuild

      mkdir -p work
      IMAGE="$PWD/work/shimboot.img"

      echo "Copying raw-rootfs image..."
      cp ${rootfsImage}/nixos.img work/rootfs.img

      echo "Calculating rootfs size..."
      LOOPROOT=$(losetup --show -fP work/rootfs.img)
      mkdir -p mnt_src_rootfs
      mount "$${LOOPROOT}p1" mnt_src_rootfs
      ROOTFS_SIZE_MB=$(du -sm mnt_src_rootfs | cut -f1)
      umount mnt_src_rootfs
      losetup -d "$LOOPROOT"

      ROOTFS_PART_SIZE=$(( (ROOTFS_SIZE_MB * 12 / 10) + 5 ))
      TOTAL_SIZE_MB=$((1 + 32 + 20 + ROOTFS_PART_SIZE))

      echo "Creating $${TOTAL_SIZE_MB}MB image..."
      fallocate -l $${TOTAL_SIZE_MB}M "$IMAGE"

      echo "Partitioning image..."
      parted --script "$IMAGE" \
        mklabel gpt \
        mkpart stateful ext4 1MiB 2MiB \
        mkpart kernel 2MiB 34MiB \
        set 2 typecode FE3A2A5D-4F32-41A7-B725-ACCC3285A309 \
        mkpart bootloader ext2 34MiB 54MiB \
        set 3 typecode 3CB8E202-3B7E-47DD-8A3C-7FF2A13CFCEC \
        mkpart rootfs ext4 54MiB 100%

      echo "Setting up loop device for final image..."
      LOOPDEV=$(losetup --show -fP "$IMAGE")

      echo "Formatting partitions..."
      mkfs.ext4 -q "$${LOOPDEV}p1"
      dd if=${patchedKernel}/vmlinuz.patched of="$${LOOPDEV}p2" bs=1M conv=fsync
      mkfs.ext2 -q "$${LOOPDEV}p3"
      mkfs.ext4 -q "$${LOOPDEV}p4"

      echo "Populating bootloader partition..."
      mkdir -p mnt_bootloader
      mount "$${LOOPDEV}p3" mnt_bootloader
      cp -a ${bootloaderDir}/* mnt_bootloader/
      umount mnt_bootloader

      echo "Populating rootfs partition from raw-rootfs..."
      LOOPROOT=$(losetup --show -fP work/rootfs.img)
      mkdir -p mnt_src_rootfs
      mount "$${LOOPROOT}p1" mnt_src_rootfs

      mkdir -p mnt_rootfs
      mount "$${LOOPDEV}p4" mnt_rootfs
      cp -a mnt_src_rootfs/* mnt_rootfs/
      umount mnt_rootfs
      umount mnt_src_rootfs
      losetup -d "$LOOPROOT"

      losetup -d "$LOOPDEV"

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      cp work/shimboot.img "$out/shimboot.img"
      runHook postInstall
    '';

    meta = with pkgs.lib; {
      description = "Final shimboot GPT image with patched kernel, bootloader, and rootfs from raw-rootfs";
      license = licenses.unfree;
      platforms = platforms.linux;
      maintainers = [ "shimboot developers" ];
    };
  };
}