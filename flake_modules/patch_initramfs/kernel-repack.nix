{ self, nixpkgs }:

let
  system = "x86_64-linux";
  pkgs = nixpkgs.legacyPackages.${system};

  extractedKernel    = self.packages.${system}.extracted-kernel;
  extractedInitramfs = self.packages.${system}.initramfs-patching;
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

      # Copy extracted kernel blob and make it writable
      install -m644 ${extractedKernel}/kernel.bin work/kernel.bin
      KERNEL_OFFSET=$(cat ${extractedKernel}/kernel_offset.txt)
      echo "Kernel blob offset inside p2: $KERNEL_OFFSET bytes"

      # --- Step 1: Extract vmlinuz from kernel blob ---
      echo "Extracting vmlinuz from kernel blob..."
      futility vbutil_kernel --get-vmlinuz work/kernel.bin --vmlinuz-out work/vmlinuz

      # --- Step 2: Find initramfs offset in vmlinuz ---
      echo "Finding initramfs offset in vmlinuz..."
      INITRAMFS_OFFSET=$(binwalk work/vmlinuz | awk '/gzip compressed data/ {print $1; exit}')
      if [ -z "$INITRAMFS_OFFSET" ]; then
        echo "ERROR: Could not find initramfs offset"
        exit 1
      fi
      echo "Initramfs offset: $INITRAMFS_OFFSET"

      # --- Step 3: Build patched vmlinuz ---
      echo "Building patched vmlinuz..."
      dd if=work/vmlinuz of=work/vmlinuz.prefix bs=1 count=$INITRAMFS_OFFSET status=none
      cat ${extractedInitramfs}/initramfs.cpio.gz >> work/vmlinuz.prefix
      mv work/vmlinuz.prefix work/vmlinuz.patched

      # --- Step 4: Replace vmlinuz inside kernel blob ---
      echo "Finding vmlinuz offset inside kernel blob..."
      VMLINUZ_OFFSET=$(binwalk work/kernel.bin | awk '/gzip compressed data/ {print $1; exit}')
      if [ -z "$VMLINUZ_OFFSET" ]; then
        echo "ERROR: Could not find vmlinuz offset in kernel blob"
        exit 1
      fi
      echo "vmlinuz offset in kernel blob: $VMLINUZ_OFFSET"

      dd if=work/vmlinuz.patched of=work/kernel.bin bs=1 seek=$VMLINUZ_OFFSET conv=notrunc status=none

      # --- Step 5: Reinsert patched kernel blob into full p2 ---
      echo "Reinserting patched kernel blob into p2..."
      install -m644 ${extractedKernel}/p2.bin work/p2.bin
      dd if=work/kernel.bin of=work/p2.bin bs=1 seek=$KERNEL_OFFSET conv=notrunc status=none

      # Optional: verify patched blob
      echo "Verifying patched kernel blob (may fail if initramfs changed)..."
      vbutil_kernel --verify work/kernel.bin --verbose || true

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      # Output the full patched p2 partition
      cp work/p2.bin "$out/kernel-p2-patched.bin"
      runHook postInstall
    '';

    meta = with pkgs.lib; {
      description = "Patch initramfs inside ChromeOS kernel blob (wrapper-aware)";
      license = licenses.unfree;
      platforms = platforms.linux;
      maintainers = [ "shimboot developers" ];
    };
  };
}