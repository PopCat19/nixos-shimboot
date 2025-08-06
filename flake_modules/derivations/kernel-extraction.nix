{ stdenv, lib, fetchurl, cgpt, coreutils, gnugrep, gawk, shimBin }:

stdenv.mkDerivation (finalAttrs: {
  pname = "extracted-kernel";
  version = "1.0.0";
  
  # The source is the ChromeOS shim binary
  src = shimBin;
  
  # Native build dependencies
  nativeBuildInputs = [
    cgpt          # ChromeOS GPT utility for partition information
    coreutils     # For dd command
    gnugrep       # For parsing cgpt output
    gawk          # For processing partition information
  ];
  
  # Don't need to unpack since we're processing a binary file
  dontUnpack = true;
  
  # Don't need to fix up since we're just extracting data
  dontFixup = true;
  
  # Build phase - extract the kernel partition
  buildPhase = ''
    runHook preBuild
    
    echo "Extracting kernel partition (KERN-A) from $src..."
    
    # Get partition information using cgpt
    cgpt_output=$(cgpt show -i 2 "$src")
    echo "CGPT output:"
    echo "$cgpt_output"
    
    # Parse partition start and size using awk
    read -r part_start part_size _ < <(
      echo "$cgpt_output" | awk '$4 == "Label:" && $5 == "\"KERN-A\"" {print $2, $3}'
    )
    
    if [ -z "$part_start" ] || [ -z "$part_size" ]; then
      echo "ERROR: Could not find KERN-A partition information"
      exit 1
    fi
    
    echo "Partition start: $part_start, size: $part_size"
    
    # Extract the kernel partition using dd
    dd if="$src" of="extracted-kernel" bs=512 skip="$part_start" count="$part_size" status=progress
    
    # Verify the extracted kernel
    if [ ! -f "extracted-kernel" ]; then
      echo "ERROR: Kernel extraction failed - no output file created"
      exit 1
    fi
    
    kernel_size=$(stat -c%s "extracted-kernel")
    echo "Kernel extracted successfully: extracted-kernel ($kernel_size bytes)"
    
    runHook postBuild
  '';
  
  # Install phase - copy the extracted kernel to the output directory
  installPhase = ''
    runHook preInstall
    
    mkdir -p $out
    cp extracted-kernel $out/
    
    # Create a metadata file with extraction information
    cat > $out/kernel-metadata.txt << EOF
Kernel Extraction Metadata
=========================
Source: $src
Extraction Date: $(date)
Partition: KERN-A (partition 2)
Start Sector: $part_start
Size in Sectors: $part_size
Size in Bytes: $kernel_size
Extraction Method: dd + cgpt
EOF
    
    runHook postInstall
  '';
  
  # Meta information
  meta = with lib; {
    description = "Extracted ChromeOS kernel partition from shim binary";
    longDescription = ''
      This derivation extracts the KERN-A partition from a ChromeOS shim binary
      using the cgpt utility to locate the partition and dd to extract it.
      The extracted kernel can be used for further processing such as initramfs
      extraction and patching.
    '';
    license = licenses.bsd3;
    platforms = platforms.linux;
    maintainers = [ "shimboot developers" ];
  };
})