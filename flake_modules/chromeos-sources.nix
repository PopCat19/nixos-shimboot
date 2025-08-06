{ self, nixpkgs, ... }:

let
  system = "x86_64-linux";
  pkgs = nixpkgs.legacyPackages.${system};
  
  # Download and extract ChromeOS shim firmware
  chromeosShim = pkgs.stdenv.mkDerivation {
    name = "chromeos-shim";
    version = "dedede";
    
    # Download the ChromeOS firmware
    src = pkgs.fetchurl {
      url = "https://dl.cros.download/files/dedede/dedede.zip";
      sha256 = "9f5b49ce81273c25592d057a886d9034d6b8f19949d0345b7269128e33cc6f85";
    };
    
    # Native build dependencies
    nativeBuildInputs = with pkgs; [
      unzip
    ];
    
    # Unpack and extract the shim binary
    unpackPhase = ''
      runHook preUnpack
      
      echo "Unpacking ChromeOS firmware..."
      unzip $src
      
      runHook postUnpack
    '';
    
    # Install phase - find and install the shim binary
    installPhase = ''
      runHook preInstall
      
      echo "Installing ChromeOS shim binary..."
      
      # Create output directory
      mkdir -p $out
      
      # Find the shim binary (typically the largest binary file)
      echo "Searching for shim binary..."
      for file in $(find . -type f -executable); do
        if [ -f "$file" ]; then
          file_size=$(stat -c%s "$file")
          echo "Found executable: $file (size: $file_size bytes)"
          
          # Check if this looks like a firmware binary (large file)
          if [ $file_size -gt 1000000 ]; then
            echo "Installing $file as shim.bin"
            cp "$file" $out/shim.bin
            break
          fi
        fi
      done
      
      # Verify shim.bin was created
      if [ ! -f "$out/shim.bin" ]; then
        echo "ERROR: Could not find shim binary in downloaded files"
        echo "Available files:"
        find . -type f -name "*.bin" -o -name "*.img" -o -name "*.fw" | head -20
        exit 1
      fi
      
      echo "Successfully installed shim.bin ($(stat -c%s $out/shim.bin) bytes)"
      
      runHook postInstall
    '';
    
    # Meta information
    meta = with pkgs.lib; {
      description = "ChromeOS shim firmware for dedede board";
      longDescription = ''
        This derivation downloads and extracts the ChromeOS shim firmware
        from the official ChromeOS download site for the dedede board.
      '';
      license = licenses.unfree;
      platforms = platforms.linux;
      maintainers = [ "shimboot developers" ];
    };
  };
  
  # Download and extract ChromeOS recovery firmware
  chromeosRecovery = pkgs.stdenv.mkDerivation {
    name = "chromeos-recovery";
    version = "16295.54.0-dedede";
    
    # Download the ChromeOS recovery image
    src = pkgs.fetchurl {
      url = "https://dl.google.com/dl/edgedl/chromeos/recovery/chromeos_16295.54.0_dedede_recovery_stable-channel_DededeMPKeys-v54.bin.zip";
      sha256 = "IbflWCE9x6Xvt67SfdGFEWTs4184soTKfjggGhV7kzA=";
    };
    
    # Native build dependencies
    nativeBuildInputs = with pkgs; [
      unzip
    ];
    
    # Unpack and extract the recovery binary
    unpackPhase = ''
      runHook preUnpack
      
      echo "Unpacking ChromeOS recovery image..."
      unzip $src
      
      runHook postUnpack
    '';
    
    # Install phase - find and install the recovery binary
    installPhase = ''
      runHook preInstall
      
      echo "Installing ChromeOS recovery binary..."
      
      # Create output directory
      mkdir -p $out
      
      # Find the recovery binary (typically the largest binary file)
      echo "Searching for recovery binary..."
      for file in $(find . -type f); do
        if [ -f "$file" ]; then
          file_size=$(stat -c%s "$file")
          echo "Found file: $file (size: $file_size bytes)"
          
          # Check if this looks like a firmware binary (large file)
          if [ $file_size -gt 1000000 ]; then
            echo "Installing $file as recovery.bin"
            cp "$file" $out/recovery.bin
            break
          fi
        fi
      done
      
      # Verify recovery.bin was created
      if [ ! -f "$out/recovery.bin" ]; then
        echo "ERROR: Could not find recovery binary in downloaded files"
        echo "Available files:"
        find . -type f -name "*.bin" -o -name "*.img" -o -name "*.fw" | head -20
        exit 1
      fi
      
      echo "Successfully installed recovery.bin ($(stat -c%s $out/recovery.bin) bytes)"
      
      runHook postInstall
    '';
    
    # Meta information
    meta = with pkgs.lib; {
      description = "ChromeOS recovery firmware for dedede board";
      longDescription = ''
        This derivation downloads and extracts the ChromeOS recovery firmware
        from the official Google download site for the dedede board.
      '';
      license = licenses.unfree;
      platforms = platforms.linux;
      maintainers = [ "shimboot developers" ];
    };
  };
  
in {
  # Packages providing ChromeOS firmware sources
  packages.${system} = {
    chromeos-shim = chromeosShim;
    chromeos-recovery = chromeosRecovery;
  };
}