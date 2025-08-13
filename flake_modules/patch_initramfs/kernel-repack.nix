{ self, nixpkgs }:

let
  system = "x86_64-linux";
  pkgs = nixpkgs.legacyPackages.${system};

  extractedInitramfs = self.packages.${system}.initramfs-patching;
  extractedKernel    = self.packages.${system}.extracted-kernel;
in {
  packages.${system}.kernel-repack = pkgs.stdenv.mkDerivation {
    name = "kernel-repack";
    src = extractedKernel;

    nativeBuildInputs = with pkgs; [
      coreutils
      binwalk
      gawk
      gnugrep
      gzip
      vboot_reference   # provides futility
    ];

    buildPhase = ''
      set -euo pipefail
      runHook preBuild

      mkdir -p work
      cp ${extractedKernel}/kernel.bin work/kernel.bin
      chmod +w work/kernel.bin

      echo "Extracting vmlinuz from original signed kernel blob..."
      futility vbutil_kernel --get-vmlinuz work/kernel.bin --vmlinuz-out work/vmlinuz

      echo "Finding initramfs offset in vmlinuz..."
      INITRAMFS_OFFSET=$(binwalk work/vmlinuz | awk '/gzip compressed data/ {print $1; exit}')
      if [ -z "$INITRAMFS_OFFSET" ]; then
        echo "ERROR: Could not find initramfs offset"
        exit 1
      fi
      echo "Initramfs offset: $INITRAMFS_OFFSET"

      echo "Building patched vmlinuz..."
      dd if=work/vmlinuz of=work/vmlinuz.prefix bs=1 count=$INITRAMFS_OFFSET status=none
      cat ${extractedInitramfs}/initramfs.cpio.gz >> work/vmlinuz.prefix
      mv work/vmlinuz.prefix work/vmlinuz.patched

      echo "Finding vmlinuz offset inside kernel.bin..."
      VMLINUZ_OFFSET=$(binwalk work/kernel.bin | awk '/gzip compressed data/ {print $1; exit}')
      if [ -z "$VMLINUZ_OFFSET" ]; then
        echo "ERROR: Could not find vmlinuz offset in kernel.bin"
        exit 1
      fi
      echo "vmlinuz offset in kernel.bin: $VMLINUZ_OFFSET"

      echo "Patching vmlinuz inside kernel.bin..."
      dd if=work/vmlinuz.patched of=work/kernel.bin bs=1 seek=$VMLINUZ_OFFSET conv=notrunc status=none

      echo "Verifying final kernel blob signature..."
      futility vbutil_kernel --verify work/kernel.bin --verbose || true

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      cp work/kernel.bin "$out/kernel.bin"
      runHook postInstall
    '';

    meta = with pkgs.lib; {
      description = "Patch initramfs inside original signed ChromeOS kernel blob in-place without re-signing";
      license = licenses.unfree;
      platforms = platforms.linux;
      maintainers = [ "shimboot developers" ];
    };
  };
}