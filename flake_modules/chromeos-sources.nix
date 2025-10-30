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

  # ChromeOS shim firmware (direct download model)
  #
  # Each board fetches a single .zip blob, avoiding manifest chunk assembly.
  # Example URL: https://dl.cros.download/files/dedede/dedede.zip
  #
  # You must precompute and fill in the sha256 for your target board.
  shimUrls = {
    dedede = {
      url = "https://dl.cros.download/files/dedede/dedede.zip";
      sha256 = "sha256-y2yOK8UYyQXqDwH/nRVmDgFv8I7FyBBCPOngWfFAaxY=";
    };
    hatch = {
      url = "https://dl.cros.download/files/hatch/hatch.zip";
      sha256 = "sha256-1111111111111111111111111111111111111111111=";
    };
    nissa = {
      url = "https://dl.cros.download/files/nissa/nissa.zip";
      sha256 = "sha256-2222222222222222222222222222222222222222222=";
    };
    zork = {
      url = "https://dl.cros.download/files/zork/zork.zip";
      sha256 = "sha256-3333333333333333333333333333333333333333333=";
    };
    grunt = {
      url = "https://dl.cros.download/files/grunt/grunt.zip";
      sha256 = "sha256-4444444444444444444444444444444444444444444=";
    };
    snappy = {
      url = "https://dl.cros.download/files/snappy/snappy.zip";
      sha256 = "sha256-5555555555555555555555555555555555555555555=";
    };
    octopus = {
      url = "https://dl.cros.download/files/octopus/octopus.zip";
      sha256 = "sha256-6666666666666666666666666666666666666666666=";
    };
  };

  shimData = shimUrls.${board} or (throw "Unsupported board ${board}: add to shimUrls set.");

  chromeosShim = pkgs.stdenv.mkDerivation {
    name = "chromeos-shim-${board}";
    version = board;

    src = pkgs.fetchurl {
      inherit (shimData) url sha256;
    };

    nativeBuildInputs = [pkgs.unzip];
    buildCommand = ''
      echo "Extracting ${board}.zip -> shim.bin..."
      unzip -p "$src" > "$out"
    '';

    meta = with pkgs.lib; {
      description = "Direct ChromeOS shim binary for board ${board}";
      license = licenses.unfree;
      maintainers = ["shimboot developers"];
      platforms = platforms.linux;
    };
  };

  # Define helper for recovery derivations
  defineRecovery = boardData:
    pkgs.stdenv.mkDerivation {
      name = "chromeos-recovery-${boardData.board}";
      version = boardData.board;

      src = pkgs.fetchurl { inherit (boardData) url sha256; };
      nativeBuildInputs = [ pkgs.unzip ];

      unpackPhase = ''
        runHook preUnpack
        echo "🔍 Unpacking recovery for ${boardData.board}..."
        unzip -q "$src"
        runHook postUnpack
      '';

      installPhase = ''
        runHook preInstall
        mkdir -p "$out"
        echo "Installing recovery image..."
        find . -type f -size +1M | head -1 | while read f; do
          cp "$f" "$out/recovery.bin"
          echo "✓ Installed $(basename "$f")"
        done
        runHook postInstall
      '';

      meta = with pkgs.lib; {
        description = "ChromeOS recovery image for ${boardData.board} board";
        license = licenses.unfree;
        platforms = platforms.linux;
        maintainers = ["shimboot developers"];
      };
    };

  recoveryDefs = {
    dedede = defineRecovery {
      board = "dedede";
      url = "https://dl.google.com/dl/edgedl/chromeos/recovery/chromeos_13597.105.0_dedede_recovery_stable-channel_mp-v3.bin.zip";
      sha256 = "sha256-4YNU6qHF/LF/znVJ1pOJpI+NJYB/B/TGGMaHM5uyJhQ=";
    };
    zork = defineRecovery {
      board = "zork";
      url = "https://dl.google.com/dl/edgedl/chromeos/recovery/chromeos_13505.73.0_zork_recovery_stable-channel_mp-v4.bin.zip";
      sha256 = "sha256-WGhEKw68CGEhPcXVTRUSrYguUBPUnKnPH28338PHmDM=";
    };
    hatch = defineRecovery {
      board = "hatch";
      url = "https://dl.google.com/dl/edgedl/chromeos/recovery/chromeos_12739.94.0_hatch_recovery_stable-channel_mp-v4.bin.zip";
      sha256 = "sha256-H34UUn4iwo2wuOAxE4LjbkynUmE8BKHYkUKPagIji6Q=";
    };
    nissa = defineRecovery {
      board = "nissa";
      url = "https://dl.google.com/dl/edgedl/chromeos/recovery/chromeos_15236.80.0_nissa_recovery_stable-channel_mp-v2.bin.zip";
      sha256 = "sha256-dfNnmYrjIIpDVcp4Dh6OLoRmami4N4+XCPsqXjbITog=";
    };
    octopus = defineRecovery {
      board = "octopus";
      url = "https://dl.google.com/dl/edgedl/chromeos/recovery/chromeos_11316.165.0_octopus_recovery_stable-channel_mp-v5.bin.zip";
      sha256 = "sha256-wZS7P8Ad2xYTPb8RtT4YiH9SXGCclped/nls+Y+XCRQ=";
    };
    snappy = defineRecovery {
      board = "snappy";
      url = "https://dl.google.com/dl/edgedl/chromeos/recovery/chromeos_9334.72.0_snappy_recovery_stable-channel_mp.bin.zip";
      sha256 = "sha256-Bh7YW9xl0KDIW9nNXR1m+xUgZumQJ421B5QgpJkoGEo=";
    };
    grunt = defineRecovery {
      board = "grunt";
      url = "https://dl.google.com/dl/edgedl/chromeos/recovery/chromeos_11151.113.0_grunt_recovery_stable-channel_mp-v5.bin.zip";
      sha256 = "sha256-aIYRcj8+Lx5PLz9PWfYp4xnzy9f5TNYnRp9S5DdrlW4=";
    };
  };

  chromeosRecovery = recoveryDefs.${board} or (throw "Unsupported board ${board} for recovery.");
in {
  packages.${system} = {
    "chromeos-shim-${board}" = chromeosShim;
    "chromeos-recovery-${board}" = chromeosRecovery;
  };
}
