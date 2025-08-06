{ stdenv, lib, fetchurl, binwalk, xz, cpio, coreutils, gnugrep, gawk, jq, extractedKernel }:

stdenv.mkDerivation (finalAttrs: {
  pname = "extracted-initramfs";
  version = "1.0.0";
  
  # The source is the extracted kernel from the previous derivation
  src = extractedKernel;
  
  # Native build dependencies
  nativeBuildInputs = [
    binwalk       # Firmware analysis tool for finding compression offsets
    xz            # XZ compression utility for decompression
    cpio          # Archive utility for extracting initramfs
    coreutils     # Basic utilities (dd, stat, etc.)
    gnugrep       # For parsing binwalk output
    gawk          # For processing binwalk JSON output
    jq            # For parsing binwalk JSON output
  ];
  
  # Don't need to unpack since we're processing a binary file
  dontUnpack = true;
  
  # Don't need to fix up since we're just extracting data
  dontFixup = true;
  
  # Build phase - extract the initramfs from the kernel
  buildPhase = ''
    runHook preBuild
    
    echo "Extracting initramfs from kernel..."
    
    # Stage 1: Find gzip offset using binwalk
    echo "Stage 1: Finding gzip offset..."
    
    # Create temporary log file for binwalk output
    gzip_log=$(mktemp)
    binwalk -y gzip -l "$gzip_log" "$src"
    
    # Extract gzip offset from binwalk output
    gzip_offset=$(grep '"offset"' "$gzip_log" | awk -F': ' '{print $2}' | sed 's/,//')
    rm "$gzip_log"
    
    if [ -z "$gzip_offset" ]; then
      echo "ERROR: Could not find gzip offset in kernel"
      exit 1
    fi
    
    echo "Gzip offset: $gzip_offset"
    
    # Stage 1: Decompress kernel
    echo "Stage 1: Decompressing kernel..."
    
    # Try standard decompression first
    if ! dd if="$src" bs=1 skip="$gzip_offset" 2>/dev/null | zcat >decompressed_kernel.bin 2>/dev/null; then
      echo "Standard decompression failed, trying with --force option..."
      # Try with --force option for ChromeOS kernels
      if ! dd if="$src" bs=1 skip="$gzip_offset" 2>/dev/null | zcat --force >decompressed_kernel.bin 2>/dev/null; then
        echo "ERROR: Kernel decompression failed even with --force option"
        exit 1
      fi
    fi
    
    # Verify decompressed kernel
    if [ ! -f "decompressed_kernel.bin" ]; then
      echo "ERROR: Kernel decompression failed - no output file created"
      exit 1
    fi
    
    kernel_size=$(stat -c%s "decompressed_kernel.bin")
    echo "Kernel decompressed successfully ($kernel_size bytes)"
    
    # Stage 2: Find XZ offset using binwalk
    echo "Stage 2: Finding XZ offset..."
    
    # Create temporary log file for binwalk output
    xz_log=$(mktemp)
    binwalk -l "$xz_log" "decompressed_kernel.bin"
    
    # Extract XZ offset from binwalk JSON output
    xz_offset=$(cat "$xz_log" | jq '.[0].Analysis.file_map[] | select(.description | contains("XZ compressed data")) | .offset')
    rm "$xz_log"
    
    if [ -z "$xz_offset" ]; then
      echo "ERROR: Could not find XZ offset in decompressed kernel"
      exit 1
    fi
    
    echo "XZ offset: $xz_offset"
    
    # Stage 2: Extract XZ cpio archive
    echo "Stage 2: Extracting XZ cpio archive..."
    
    # Create output directory for initramfs
    mkdir -p initramfs-extracted
    
    # Extract the XZ-compressed cpio archive
    # Allow for some errors which are expected with ChromeOS initramfs
    if ! dd if="decompressed_kernel.bin" bs=1 skip="$xz_offset" 2>/dev/null | xz -dc 2>/dev/null | cpio -idm -D initramfs-extracted 2>/dev/null; then
      echo "Some cpio extraction errors occurred (this is expected for ChromeOS initramfs)"
      echo "Continuing with extraction..."
    fi
    
    # Verify initramfs extraction
    if [ ! -d "initramfs-extracted" ]; then
      echo "ERROR: Initramfs extraction failed - no output directory created"
      exit 1
    fi
    
    if [ -z "$(ls -A initramfs-extracted 2>/dev/null)" ]; then
      echo "ERROR: Initramfs extraction failed - empty directory"
      exit 1
    fi
    
    # Check for key files
    key_files=("init" "bin" "sbin" "lib")
    for file in "${key_files[@]}"; do
      if [ ! -e "initramfs-extracted/$file" ]; then
        echo "WARNING: Key file/directory not found: $file"
      fi
    done
    
    echo "Initramfs extracted successfully to: initramfs-extracted"
    echo "Key files in extracted initramfs:"
    [ -f "initramfs-extracted/init" ] && echo "  - init script found"
    [ -d "initramfs-extracted/bin" ] && echo "  - bin directory found"
    [ -d "initramfs-extracted/sbin" ] && echo "  - sbin directory found"
    [ -d "initramfs-extracted/lib" ] && echo "  - lib directory found"
    
    runHook postBuild
  '';
  
  # Install phase - copy the extracted initramfs to the output directory
  installPhase = ''
    runHook preInstall
    
    # Copy the entire initramfs directory structure
    cp -r initramfs-extracted $out/
    
    # Create a metadata file with extraction information
    cat > $out/initramfs-metadata.txt << EOF
Initramfs Extraction Metadata
===========================
Source: $src
Extraction Date: $(date)
Gzip Offset: $gzip_offset
Decompressed Kernel Size: $kernel_size bytes
XZ Offset: $xz_offset
Extraction Method: binwalk + xz + cpio
Expected ChromeOS Quirks: Handled
EOF
    
    runHook postInstall
  '';
  
  # Meta information
  meta = with lib; {
    description = "Extracted initramfs from ChromeOS kernel";
    longDescription = ''
      This derivation extracts the initramfs from a ChromeOS kernel using binwalk
      to locate compression offsets, xz for decompression, and cpio for archive
      extraction. It handles ChromeOS-specific compression quirks and expected
      extraction warnings. The extracted initramfs can be used for further
      processing such as bootloader injection.
    '';
    license = licenses.bsd3;
    platforms = platforms.linux;
    maintainers = [ "shimboot developers" ];
  };
})