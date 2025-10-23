{
  self,
  nixpkgs,
  board ? "dedede",
  ...
}: let
  system = "x86_64-linux";
  pkgs = import nixpkgs {
    inherit system;
    config = {
      allowUnfree = true;
      allowUnfreePredicate = pkg:
        builtins.elem (nixpkgs.lib.getName pkg) [
          "chromeos-shim-${board}"
          "chromeos-recovery-${board}"
        ];
    };
  };

  # Import generated manifest from fetch-manifest.sh
  boardManifest = import ../${board}-manifest.nix;

  chunkBaseUrl = "https://cdn.cros.download/files/${board}";

  # Fetch each chunk as a fixed-output derivation
  chunkDrvs =
    map (
      chunk:
        pkgs.fetchurl {
          url = "${chunkBaseUrl}/${chunk.name}";
          sha256 = chunk.sha256;
          curlOpts = "--retry-delay 10";
        }
    )
    boardManifest.chunks;

  # ChromeOS shim firmware - proprietary binary from Google
  # This derivation downloads and repackages ChromeOS firmware blobs.
  # The output remains under Google's proprietary license terms and is marked unfree.
  chromeosShim = pkgs.stdenv.mkDerivation {
    name = "chromeos-shim-${board}";
    version = board;

    # Fixed-output derivation: Nix knows the final zip hash
    outputHashMode = "flat";
    outputHashAlgo = "sha256";
    outputHash = boardManifest.hash;

    nativeBuildInputs = [pkgs.unzip];

    buildCommand = ''
      echo "Joining ${toString (builtins.length boardManifest.chunks)} chunks for ${board}..."
      cat ${pkgs.lib.concatStringsSep " " chunkDrvs} > ${board}.zip

      echo "Extracting shim.bin..."
      unzip -p ${board}.zip > $out
    '';

    meta = with pkgs.lib; {
      description = "ChromeOS shim firmware for ${board} board";
      longDescription = ''
        Downloads and extracts the ChromeOS shim firmware for the ${board} board
        from the official ChromeOS CDN, using the manifest + chunk method.
      '';
      license = licenses.unfree;
      platforms = platforms.linux;
      maintainers = ["shimboot developers"];
    };
  };

  # ChromeOS recovery firmware - proprietary binary from Google
  # This derivation downloads and extracts ChromeOS recovery images.
  # The output remains under Google's proprietary license terms and is marked unfree.
  chromeosRecovery = pkgs.stdenv.mkDerivation {
    name = "chromeos-recovery-${board}";
    version = "${board}";

    src = pkgs.fetchurl {
      # NOTE: Recovery URL must be board-specific; update per board or parameterize
      url = "https://dl.google.com/dl/edgedl/chromeos/recovery/chromeos_16295.54.0_${board}_recovery_stable-channel_${board}MPKeys-v54.bin.zip";
      sha256 = nixpkgs.lib.fakeSha256; # Replace with actual hash per board
    };

    nativeBuildInputs = [pkgs.unzip];

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
      description = "ChromeOS recovery firmware for ${board} board";
      license = licenses.unfree;
      platforms = platforms.linux;
      maintainers = ["shimboot developers"];
    };
  };
in {
  packages.${system} = {
    "chromeos-shim-${board}" = chromeosShim;
    "chromeos-recovery-${board}" = chromeosRecovery;
  };
}
