{ self, nixpkgs, ... }:

let
  system = "x86_64-linux";
  pkgs = nixpkgs.legacyPackages.${system};
  
  # Import the chromeos-shim package from our own flake
  chromeosShim = self.packages.${system}.chromeos-shim;
  
  # Extract kernel partition from ChromeOS shim image
  extractKernel = pkgs.stdenv.mkDerivation {
    name = "extracted-kernel";
    version = "1.0.0";
    
    # The ChromeOS shim image is our source
    src = chromeosShim;
    
    # Native build dependencies for kernel extraction
    nativeBuildInputs = with pkgs; [
      util-linux # for losetup and other utilities
      e2fsprogs # for filesystem utilities
      gptfdisk # for cgpt
    ];
    
    # Build phase - extract kernel partition
    buildPhase = ''
      runHook preBuild
      
      echo "Starting kernel extraction from ChromeOS shim image..."
      
      # Create a working directory
      mkdir -p work
      cd work
      
      # Copy the shim image to our working directory
      cp ${chromeosShim}/shim.bin ./shim.bin
      
      echo "Shim image size: $(stat -c%s shim.bin) bytes"
      
      # Step 1: Create a loop device for the shim image
      echo "Creating loop device for shim image..."
      losetup -f --show shim.bin > loop_device.txt
      LOOP_DEVICE=$(cat loop_device.txt)
      echo "Created loop device: $LOOP_DEVICE"
      
      # Step 2: Copy the kernel partition (KERN-A, typically partition 2) to a temporary file
      echo "Extracting kernel partition (KERN-A)..."
      
      # Try to determine the kernel partition number
      # First try with cgpt (ChromeOS partition tool)
      if command -v cgpt >/dev/null 2>&1; then
        echo "Using cgpt to find kernel partition..."
        cgpt show $LOOP_DEVICE > partition_info.txt
        echo "Partition information:"
        cat partition_info.txt
        
        # Look for KERN-A partition (usually partition 2)
        KERNEL_PARTITION=$(grep "KERN-A" partition_info.txt | awk '{print $1}' | tr -d ':')
        if [ -z "$KERNEL_PARTITION" ]; then
          echo "KERN-A partition not found, defaulting to partition 2"
          KERNEL_PARTITION=2
        fi
      else
        echo "cgpt not available, defaulting to partition 2"
        KERNEL_PARTITION=2
      fi
      
      echo "Using kernel partition: $KERNEL_PARTITION"
      
      # Extract the kernel partition using dd
      dd if=$LOOP_DEVICE of=kernel.bin bs=512 skip=$(($KERNEL_PARTITION * 2048)) count=65536
      
      echo "Extracted kernel size: $(stat -c%s kernel.bin) bytes"
      
      # Verify the extracted kernel
      if [ ! -f kernel.bin ] || [ $(stat -c%s kernel.bin) -eq 0 ]; then
        echo "ERROR: Failed to extract kernel partition"
        exit 1
      fi
      
      # Step 3: Release the loop device
      echo "Releasing loop device..."
      losetup -d $LOOP_DEVICE
      
      echo "Kernel extraction completed successfully"
      
      runHook postBuild
    '';
    
    # Install phase - copy the extracted kernel
    installPhase = ''
      runHook preInstall
      
      echo "Installing extracted kernel..."
      
      # Create output directory
      mkdir -p $out
      
      # Copy the extracted kernel
      cp work/kernel.bin $out/kernel.bin
      
      # Copy partition information for debugging
      if [ -f work/partition_info.txt ]; then
        cp work/partition_info.txt $out/partition_info.txt
      fi
      
      echo "Successfully installed extracted kernel ($(stat -c%s $out/kernel.bin) bytes)"
      
      runHook postInstall
    '';
    
    # Meta information
    meta = with pkgs.lib; {
      description = "Extracted kernel partition from ChromeOS shim image";
      longDescription = ''
        This derivation extracts the kernel partition (KERN-A) from a ChromeOS shim image
        using loop devices and partition tools. The extracted kernel can be used for
        further processing such as initramfs extraction and patching.
      '';
      license = licenses.unfree; # inherits from ChromeOS firmware
      platforms = platforms.linux;
      maintainers = [ "shimboot developers" ];
    };
  };
  
in {
  # Package providing the extracted kernel
  packages.${system}.extracted-kernel = extractKernel;
}