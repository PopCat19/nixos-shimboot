{ stdenv, lib, fetchurl, coreutils, gnugrep, gawk, shimBin, recoveryBin ? null }:

stdenv.mkDerivation (finalAttrs: {
  pname = "harvested-kernel-modules";
  version = "1.0.0";
  
  # The source is the ChromeOS shim binary (and optionally recovery binary)
  src = if recoveryBin != null then [ shimBin recoveryBin ] else [ shimBin ];
  
  # Native build dependencies
  nativeBuildInputs = [
    coreutils     # For basic utilities
    gnugrep       # For parsing output
    gawk          # For processing text
  ];
  
  # Don't need to unpack since we're processing binary files
  dontUnpack = true;
  
  # Don't need to fix up since we're just extracting data
  dontFixup = true;
  
  # Build phase - harvest kernel modules and firmware
  buildPhase = ''
    runHook preBuild
    
    echo "Harvesting kernel modules and firmware from ChromeOS images..."
    
    # Create output directories
    mkdir -p modules/lib/modules
    mkdir -p firmware/lib/firmware
    
    # Function to extract modules from a ChromeOS image
    extract_modules() {
      local image="$1"
      local image_name=$(basename "$image")
      
      echo "Processing image: $image_name"
      
      # Check if image exists
      if [ ! -f "$image" ]; then
        echo "WARNING: Image not found: $image"
        return 1
      fi
      
      # Create temporary working directory
      local temp_dir=$(mktemp -d)
      cd "$temp_dir"
      
      # Try to extract the ROOT-A partition (typically partition 3)
      echo "Attempting to extract ROOT-A partition from $image_name..."
      
      # Get partition information using cgpt if available
      if command -v cgpt >/dev/null 2>&1; then
        cgpt_output=$(cgpt show "$image" 2>/dev/null || true)
        
        if [ -n "$cgpt_output" ]; then
          echo "Partition information for $image_name:"
          echo "$cgpt_output"
          
          # Look for ROOT-A partition (usually partition 3)
          root_part_info=$(echo "$cgpt_output" | awk '$4 == "Label:" && $5 == "\"ROOT-A\"" {print $2, $3}')
          
          if [ -n "$root_part_info" ]; then
            read -r part_start part_size <<< "$root_part_info"
            echo "Found ROOT-A partition: start=$part_start, size=$part_size"
            
            # Extract the ROOT-A partition
            dd if="$image" of="root-a.img" bs=512 skip="$part_start" count="$part_size" 2>/dev/null || true
            
            if [ -f "root-a.img" ] && [ -s "root-a.img" ]; then
              echo "ROOT-A partition extracted successfully"
              
              # Try to mount the partition and extract modules
              mkdir -p mnt
              
              # Try to determine filesystem type and mount
              if command -v mount >/dev/null 2>&1; then
                # Try ext4 first (most common for ChromeOS)
                if mount -t ext4 -o ro,loop "root-a.img" mnt 2>/dev/null; then
                  echo "Mounted ROOT-A partition (ext4)"
                  extract_from_mounted_fs "$image_name"
                  umount mnt 2>/dev/null || true
                elif mount -t ext2 -o ro,loop "root-a.img" mnt 2>/dev/null; then
                  echo "Mounted ROOT-A partition (ext2)"
                  extract_from_mounted_fs "$image_name"
                  umount mnt 2>/dev/null || true
                else
                  echo "WARNING: Could not mount ROOT-A partition"
                fi
              else
                echo "WARNING: mount command not available, skipping filesystem extraction"
              fi
            else
              echo "WARNING: Failed to extract ROOT-A partition"
            fi
          else
            echo "WARNING: ROOT-A partition not found in $image_name"
          fi
        else
          echo "WARNING: Could not get partition information for $image_name"
        fi
      else
        echo "WARNING: cgpt command not available, skipping partition extraction"
      fi
      
      # Clean up
      cd - >/dev/null
      rm -rf "$temp_dir"
    }
    
    # Function to extract modules from mounted filesystem
    extract_from_mounted_fs() {
      local image_name="$1"
      
      echo "Extracting modules from mounted filesystem..."
      
      # Look for kernel modules
      if [ -d "mnt/lib/modules" ]; then
        echo "Found kernel modules directory"
        cp -r mnt/lib/modules/* modules/lib/modules/ 2>/dev/null || true
        echo "Copied kernel modules from $image_name"
      fi
      
      # Look for firmware
      if [ -d "mnt/lib/firmware" ]; then
        echo "Found firmware directory"
        cp -r mnt/lib/firmware/* firmware/lib/firmware/ 2>/dev/null || true
        echo "Copied firmware from $image_name"
      fi
      
      # Also check /usr/lib/firmware (some systems use this path)
      if [ -d "mnt/usr/lib/firmware" ]; then
        echo "Found firmware directory in /usr/lib"
        cp -r mnt/usr/lib/firmware/* firmware/lib/firmware/ 2>/dev/null || true
        echo "Copied firmware from /usr/lib in $image_name"
      fi
    }
    
    # Extract modules from shim binary
    extract_modules "${shimBin}"
    
    # Extract modules from recovery binary if provided
    if [ -n "${recoveryBin}" ] && [ -f "${recoveryBin}" ]; then
      extract_modules "${recoveryBin}"
    else
      echo "No recovery binary provided, skipping..."
    fi
    
    # Verify that we extracted something
    if [ -z "$(ls -A modules/lib/modules 2>/dev/null)" ] && [ -z "$(ls -A firmware/lib/firmware 2>/dev/null)" ]; then
      echo "WARNING: No kernel modules or firmware were extracted"
      echo "This might be normal if the images don't contain accessible partitions"
    else
      echo "Kernel modules and firmware harvesting completed"
      
      # List what we found
      if [ -n "$(ls -A modules/lib/modules 2>/dev/null)" ]; then
        echo "Kernel modules found:"
        find modules/lib/modules -type f -name "*.ko" | head -10
        local module_count=$(find modules/lib/modules -type f -name "*.ko" | wc -l)
        echo "Total kernel modules: $module_count"
      fi
      
      if [ -n "$(ls -A firmware/lib/firmware 2>/dev/null)" ]; then
        echo "Firmware files found:"
        find firmware/lib/firmware -type f | head -10
        local firmware_count=$(find firmware/lib/firmware -type f | wc -l)
        echo "Total firmware files: $firmware_count"
      fi
    fi
    
    runHook postBuild
  '';
  
  # Install phase - copy the harvested modules and firmware
  installPhase = ''
    runHook preInstall
    
    # Copy modules if any were found
    if [ -n "$(ls -A modules/lib/modules 2>/dev/null)" ]; then
      mkdir -p $out/lib/modules
      cp -r modules/lib/modules/* $out/lib/modules/
      echo "Kernel modules installed to: $out/lib/modules"
    fi
    
    # Copy firmware if any was found
    if [ -n "$(ls -A firmware/lib/firmware 2>/dev/null)" ]; then
      mkdir -p $out/lib/firmware
      cp -r firmware/lib/firmware/* $out/lib/firmware/
      echo "Firmware installed to: $out/lib/firmware"
    fi
    
    # Create a metadata file with harvesting information
    cat > $out/harvesting-metadata.txt << EOF
Kernel Module and Firmware Harvesting Metadata
=============================================
Source Images: ${toString src}
Harvesting Date: $(date)
Harvesting Method: Partition extraction + filesystem mounting
Shim Binary: ${shimBin}
${if recoveryBin != null then "Recovery Binary: ${recoveryBin}" else "Recovery Binary: Not provided"}

Extraction Results:
- Kernel modules: $([ -n "$(ls -A modules/lib/modules 2>/dev/null)" ] && echo "Found" || echo "None found")
- Firmware files: $([ -n "$(ls -A firmware/lib/firmware 2>/dev/null)" ] && echo "Found" || echo "None found")

Note: This derivation attempts to extract kernel modules and firmware from
ChromeOS system partitions. Success depends on the accessibility of the
partitions and the availability of required tools (cgpt, mount).
EOF
    
    runHook postInstall
  '';
  
  # Meta information
  meta = with lib; {
    description = "Harvested kernel modules and firmware from ChromeOS images";
    longDescription = ''
      This derivation harvests kernel modules and firmware from ChromeOS shim and
      recovery images. It attempts to extract the ROOT-A partition, mount it, and
      copy the kernel modules and firmware directories for use in NixOS systems.
      
      The extraction process requires cgpt for partition information and mount for
      filesystem access. Not all ChromeOS images may yield extractable modules
      depending on their configuration and encryption status.
    '';
    license = licenses.bsd3;
    platforms = platforms.linux;
    maintainers = [ "shimboot developers" ];
  };
})