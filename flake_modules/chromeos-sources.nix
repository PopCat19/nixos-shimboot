# chromeos-sources.nix
#
# Purpose: Fetch ChromeOS shim and recovery firmware for board-specific builds
#
# This module:
# - Downloads ChromeOS shim firmware from CDN using manifest-based chunk assembly
# - Fetches ChromeOS recovery images for supported boards
# - Provides unfree-licensed proprietary firmware as Nix derivations
{
  nixpkgs,
  board ? "dedede",
  ...
}:
let
  system = "x86_64-linux";
  pkgs = import nixpkgs {
    inherit system;
    config = {
      allowUnfree = true;
      allowUnfreePredicate =
        pkg:
        builtins.elem (nixpkgs.lib.getName pkg) [
          "chromeos-shim-${board}"
          "chromeos-recovery-${board}"
        ];
    };
  };

  boardManifest = import ../manifests/${board}-manifest.nix;

  chunkBaseUrl = "https://cdn.cros.download/files/${board}";

  chunkDrvs = map (
    chunk:
    pkgs.fetchurl {
      url = "${chunkBaseUrl}/${chunk.name}";
      inherit (chunk) sha256;
      curlOpts = "--retry-delay 10";
    }
  ) boardManifest.chunks;

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

    nativeBuildInputs = [ pkgs.unzip ];

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
      maintainers = [ "shimboot developers" ];
    };
  };

  # ChromeOS recovery firmware - proprietary binary from Google
  # This derivation downloads and extracts ChromeOS recovery images.
  # The output remains under Google's proprietary license terms and is marked unfree.
  chromeosRecovery =
    let
      recoveryUrls = {
        dedede = {
          url = "https://dl.google.com/dl/edgedl/chromeos/recovery/chromeos_13597.105.0_dedede_recovery_stable-channel_mp-v3.bin.zip";
          sha256 = "sha256-4YNU6qHF/LF/znVJ1pOJpI+NJYB/B/TGGMaHM5uyJhQ=";
        };
        grunt = {
          url = "https://dl.google.com/dl/edgedl/chromeos/recovery/chromeos_11151.113.0_grunt_recovery_stable-channel_mp-v5.bin.zip";
          sha256 = "sha256-aIYRcj8+Lx5PLz9PWfYp4xnzy9f5TNYnRp9S5DdrlW4=";
        };
        hatch = {
          url = "https://dl.google.com/dl/edgedl/chromeos/recovery/chromeos_12739.94.0_hatch_recovery_stable-channel_mp-v4.bin.zip";
          sha256 = "sha256-H34UUn4iwo2wuOAxE4LjbkynUmE8BKHYkUKPagIji6Q=";
        };
        nissa = {
          url = "https://dl.google.com/dl/edgedl/chromeos/recovery/chromeos_15236.80.0_nissa_recovery_stable-channel_mp-v2.bin.zip";
          sha256 = "sha256-dfNnmYrjIIpDVcp4Dh6OLoRmami4N4+XCPsqXjbITog=";
        };
        octopus = {
          url = "https://dl.google.com/dl/edgedl/chromeos/recovery/chromeos_11316.165.0_octopus_recovery_stable-channel_mp-v5.bin.zip";
          sha256 = "sha256-wZS7P8Ad2xYTPb8RtT4YiH9SXGCclped/nls+Y+XCRQ=";
        };
        snappy = {
          url = "https://dl.google.com/dl/edgedl/chromeos/recovery/chromeos_9334.72.0_snappy_recovery_stable-channel_mp.bin.zip";
          sha256 = "sha256-Bh7YW9xl0KDIW9nNXR1m+xUgZumQJ421B5QgpJkoGEo=";
        };
        zork = {
          url = "https://dl.google.com/dl/edgedl/chromeos/recovery/chromeos_13505.73.0_zork_recovery_stable-channel_mp-v4.bin.zip";
          sha256 = "sha256-WGhEKw68CGEhPcXVTRUSrYguUBPUnKnPH28338PHmDM=";
        };
      };
      recoveryData = recoveryUrls.${board} or (throw "Unsupported board: ${board}");
    in
    pkgs.stdenv.mkDerivation {
      name = "chromeos-recovery-${board}";
      version = "${board}";

      src = pkgs.fetchurl {
        inherit (recoveryData) url sha256;
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
        description = "ChromeOS recovery firmware for ${board} board";
        license = licenses.unfree;
        platforms = platforms.linux;
        maintainers = [ "shimboot developers" ];
      };
    };
in
{
  packages.${system} = {
    "chromeos-shim-${board}" = chromeosShim;
    "chromeos-recovery-${board}" = chromeosRecovery;
  };
}
