{ self, nixpkgs }:

let
  system = "x86_64-linux";
  pkgs = nixpkgs.legacyPackages.${system};

  # Inputs from previous steps
  extractedInitramfs = self.packages.${system}.initramfs-patching;
  extractedKernel    = self.packages.${system}.initramfs-extraction;
  extractedKernelBin = self.packages.${system}.extracted-kernel;

  # Local dev keys (decoded from googlesource base64)
  devKeys = ./../../kernel_data_key.vbprivk;
  devKeyblock = ./../../kernel.keyblock;
in {
  packages.${system}.kernel-repack = pkgs.stdenv.mkDerivation {
    name = "kernel-repack";
    src = extractedKernel;

    nativeBuildInputs = with pkgs; [
      coreutils
      vboot_reference
      gzip
    ];

    buildPhase = ''
      set -euo pipefail
      runHook preBuild

      mkdir -p work

      echo "Copying vmlinuz and patched initramfs..."
      cp $src/vmlinuz work/vmlinuz
      cp ${extractedInitramfs}/initramfs.cpio.gz work/initramfs.cpio.gz

      echo "Combining vmlinuz and initramfs..."
      cat work/vmlinuz work/initramfs.cpio.gz > work/vmlinuz-with-initramfs

      echo "Extracting original kernel command line..."
      if [ -f $src/cmdline ]; then
        cp $src/cmdline work/cmdline
      else
        echo "console= loglevel=7 init=/sbin/init rootwait ro" > work/cmdline
      fi

      echo "Creating minimal bootloader stub (1 byte)..."
      dd if=/dev/zero of=work/bootloader bs=1 count=1 status=none

      echo "Packing new ChromeOS kernel blob..."
      futility vbutil_kernel \
        --pack work/kernel.bin \
        --keyblock ${devKeyblock} \
        --signprivate ${devKeys} \
        --version 1 \
        --vmlinuz work/vmlinuz-with-initramfs \
        --bootloader work/bootloader \
        --config work/cmdline \
        --arch x86 \
        --flags 0x1

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      cp work/kernel.bin "$out/kernel.bin"
      runHook postInstall
    '';

    meta = with pkgs.lib; {
      description = "Repack ChromeOS kernel with patched initramfs (dev keys, empty bootloader stub)";
      license = licenses.unfree;
      platforms = platforms.linux;
      maintainers = [ "shimboot developers" ];
    };
  };
}