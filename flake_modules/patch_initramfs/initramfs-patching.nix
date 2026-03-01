# initramfs-patching.nix
#
# Purpose: Overlay custom bootloader files onto extracted ChromeOS initramfs
#
# This module:
# - Takes extracted initramfs and replaces init with custom bootloader
# - Overlays bootloader directory contents into initramfs
# - Outputs patched initramfs directory and tar archive
{
  self,
  nixpkgs,
  board ? "dedede",
}:
let
  system = "x86_64-linux";
  pkgs = import nixpkgs {
    inherit system;
    config = {
      allowUnfreePredicate =
        pkg:
        builtins.elem (nixpkgs.lib.getName pkg) [
          "initramfs-extraction-${board}"
          "initramfs-patching-${board}"
        ];
    };
  };

  extractedInitramfs = self.packages.${system}."initramfs-extraction-${board}";
  bootloaderDir = ./../../bootloader;
  extractedKernel = self.packages.${system}."extracted-kernel-${board}";

  # Self-contained cryptsetup bundle for the busybox initramfs.
  # Copies the binary, all shared libraries, and the ELF interpreter into
  # a flat layout. A wrapper invokes ld-linux with an explicit library path
  # so no system linker config is needed inside the initramfs.
  cryptsetupBundle =
    pkgs.runCommand "cryptsetup-initramfs-bundle"
      {
        nativeBuildInputs = [ pkgs.patchelf ];
      }
      ''
            mkdir -p $out/{bin,lib,libexec}

            CRYPTSETUP="${pkgs.cryptsetup}/bin/cryptsetup"
            cp "$CRYPTSETUP" $out/libexec/cryptsetup.bin

            INTERP="$(patchelf --print-interpreter "$CRYPTSETUP")"
            INTERP_NAME="$(basename "$INTERP")"
            cp "$INTERP" "$out/lib/$INTERP_NAME"

            ldd "$CRYPTSETUP" | while IFS= read -r line; do
              lib_path="$(echo "$line" | grep -oP '/nix/store/\S+' || true)"
              [ -f "$lib_path" ] && cp -n "$lib_path" "$out/lib/" 2>/dev/null || true
            done

            cat > $out/bin/cryptsetup << WRAPPER
        #!/bin/sh
        exec /usr/lib/shimboot/$INTERP_NAME --library-path /usr/lib/shimboot /usr/libexec/cryptsetup.bin "\$@"
        WRAPPER
            chmod +x $out/bin/cryptsetup
      '';
in
{
  packages.${system}."initramfs-patching-${board}" = pkgs.stdenv.mkDerivation {
    name = "initramfs-patching-${board}";
    src = extractedInitramfs;

    nativeBuildInputs = with pkgs; [
      coreutils
      findutils
      cpio
      gzip
      xz
      zstd
      lz4
    ];

    buildPhase = ''
      set -euo pipefail
      runHook preBuild

      mkdir -p work
      echo "Unpacking initramfs.tar from extracted initramfs into work/ ..."
      tar -xf "$src/initramfs.tar" -C work

      echo "Removing original init from initramfs ..."
      rm -f work/init

      echo "Overlaying bootloader files into initramfs ..."
      cp -a ${bootloaderDir}/* work/ || true

      echo "Ensuring files in bin/ are executable if present ..."
      if [ -d work/bin ]; then
        chmod +x work/bin/* || true
      fi

      echo "Bundling cryptsetup for LUKS2 support ..."
      mkdir -p work/usr/lib/shimboot work/usr/libexec
      cp -a ${cryptsetupBundle}/lib/. work/usr/lib/shimboot/
      cp ${cryptsetupBundle}/libexec/cryptsetup.bin work/usr/libexec/cryptsetup.bin
      cp ${cryptsetupBundle}/bin/cryptsetup work/bin/cryptsetup
      chmod +x work/bin/cryptsetup work/usr/libexec/cryptsetup.bin
      echo "cryptsetup bundle installed"

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p "$out"

      cp ${extractedKernel}/kernel.bin "$out/original-kernel.bin" || true

      mkdir -p "$out/patched-initramfs"
      cp -a work/* "$out/patched-initramfs/"

      (cd "$out/patched-initramfs" && tar -cf "$out/initramfs.tar" .)

      runHook postInstall
    '';

    meta = with pkgs.lib; {
      description = "Patch ChromeOS initramfs with custom bootloader files";
      license = licenses.unfree;
      platforms = platforms.linux;
      maintainers = [ "shimboot developers" ];
    };
  };
}
