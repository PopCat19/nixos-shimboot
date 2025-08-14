{ self, nixpkgs, ... }:

let
  system = "x86_64-linux";
  pkgs = nixpkgs.legacyPackages.${system};

  # Import generated manifest from fetch-manifest.sh
  dededeManifest = import ../dedede-manifest.nix;

  chunkBaseUrl = "https://cdn.cros.download/files/dedede";

  # Fetch each chunk as a fixed-output derivation
  chunkDrvs = map (chunk:
    pkgs.fetchurl {
      url = "${chunkBaseUrl}/${chunk.name}";
      sha256 = chunk.sha256;
    }
  ) dededeManifest.chunks;

  chromeosShim = pkgs.stdenv.mkDerivation {
    name = "chromeos-shim";
    version = "dedede";

    # Fixed-output derivation: Nix knows the final zip hash
    outputHashMode = "flat";
    outputHashAlgo = "sha256";
    outputHash = dededeManifest.hash;

    nativeBuildInputs = [ pkgs.unzip ];

    buildCommand = ''
      echo "Joining ${toString (builtins.length dededeManifest.chunks)} chunks..."
      cat ${pkgs.lib.concatStringsSep " " chunkDrvs} > dedede.zip

      echo "Extracting shim.bin..."
      unzip -p dedede.zip > $out
    '';

    meta = with pkgs.lib; {
      description = "ChromeOS shim firmware for dedede board (fixed-output, manifest-based)";
      longDescription = ''
        Downloads and extracts the ChromeOS shim firmware for the dedede board
        from the official ChromeOS CDN, using the manifest + chunk method.
      '';
      license = licenses.unfree;
      platforms = platforms.linux;
      maintainers = [ "shimboot developers" ];
    };
  };

  chromeosRecovery = pkgs.stdenv.mkDerivation {
    name = "chromeos-recovery";
    version = "16295.54.0-dedede";

    src = pkgs.fetchurl {
      url = "https://dl.google.com/dl/edgedl/chromeos/recovery/chromeos_16295.54.0_dedede_recovery_stable-channel_DededeMPKeys-v54.bin.zip";
      sha256 = "IbflWCE9x6Xvt67SfdGFEWTs4184soTKfjggGhV7kzA=";
    };

    nativeBuildInputs = [ pkgs.unzip ];

    unpackPhase = ''
      runHook preUnpack
      echo "Unpacking ChromeOS recovery image..."
      unzip $src
      runHook postUnpack
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      echo "Searching for recovery binary..."
      for file in $(find . -type f); do
        file_size=$(stat -c%s "$file")
        if [ $file_size -gt 1000000 ]; then
          echo "Installing $file as recovery.bin"
          cp "$file" $out/recovery.bin
          break
        fi
      done
      if [ ! -f "$out/recovery.bin" ]; then
        echo "ERROR: Could not find recovery binary"
        exit 1
      fi
      echo "Installed recovery.bin ($(stat -c%s $out/recovery.bin) bytes)"
      runHook postInstall
    '';

    meta = with pkgs.lib; {
      description = "ChromeOS recovery firmware for dedede board";
      license = licenses.unfree;
      platforms = platforms.linux;
      maintainers = [ "shimboot developers" ];
    };
  };

in {
  packages.${system} = {
    chromeos-shim = chromeosShim;
    chromeos-recovery = chromeosRecovery;
  };
}