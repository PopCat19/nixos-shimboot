{ stdenv, lib, fetchurl, coreutils, cpio, xz, extractedKernel, patchedInitramfs }:

stdenv.mkDerivation (finalAttrs: {
  pname = "repackaged-kernel";
  version = "1.0.0";
  
  # The source is the extracted kernel from the previous derivation
  src = extractedKernel;
  
  # Native build dependencies
  nativeBuildInputs = [
    coreutils     # For dd, stat, etc.
    cpio          # For creating initramfs archive
    xz            # For compressing the initramfs
  ];
  
  # Don't need to unpack since we're processing a binary file
  dontUnpack = true;
  
  # Don't need to fix up since we're just repackaging
  dontFixup = true;
  
  # Build phase - repackage kernel with patched initramfs
  buildPhase = ''
    runHook preBuild
    
    echo "Repackaging kernel with patched initramfs..."
    
    # Verify that the extracted kernel exists
    if [ ! -f "$src" ]; then
      echo "ERROR: Extracted kernel not found: $src"
      exit 1
    fi
    
    # Verify that the patched initramfs exists
    if [ ! -d "${patchedInitramfs}" ]; then
      echo "ERROR: Patched initramfs not found: ${patchedInitramfs}"
      exit 1
    fi
    
    # Create working directory
    mkdir -p work
    cd work
    
    # Copy the original kernel
    cp "$src" original-kernel
    
    # Get kernel size for reference
    kernel_size=$(stat -c%s original-kernel)
    echo "Original kernel size: $kernel_size bytes"
    
    # Create a new initramfs archive from the patched initramfs
    echo "Creating new initramfs archive from patched initramfs..."
    
    # Change to the patched initramfs directory
    cd "${patchedInitramfs}"
    
    # Create the initramfs cpio archive
    echo "Creating cpio archive..."
    find . -print0 | cpio --null -o --format=newc > ../work/initramfs.cpio 2>/dev/null
    
    # Compress the initramfs with xz
    echo "Compressing initramfs with xz..."
    xz -z --check=crc32 --lzma2=dict=1MiB ../work/initramfs.cpio
    
    # Go back to work directory
    cd ../work
    
    # Verify the compressed initramfs was created
    if [ ! -f "initramfs.cpio.xz" ]; then
      echo "ERROR: Failed to create compressed initramfs"
      exit 1
    fi
    
    initramfs_size=$(stat -c%s initramfs.cpio.xz)
    echo "Compressed initramfs size: $initramfs_size bytes"
    
    # Now we need to find where the original initramfs is in the kernel
    # and replace it with our new one
    
    # This is a simplified approach - in practice, ChromeOS kernels have
    # specific structures that need to be handled carefully
    
    # For now, we'll create a new kernel by:
    # 1. Finding the end of the kernel proper (before initramfs)
    # 2. Appending our new initramfs
    # 3. Updating any necessary metadata
    
    echo "Analyzing kernel structure..."
    
    # Try to find the initramfs signature in the original kernel
    # Look for xz compressed data signature
    xz_offset=$(od -t x1 -A d original-kernel | grep 'fd 37 7a 58 5a 00' | head -1 | awk '{print $1}')
    
    if [ -n "$xz_offset" ]; then
      echo "Found XZ compressed data at offset: $xz_offset"
      
      # Extract the kernel part (before initramfs)
      dd if=original-kernel of=kernel-part bs=1 count="$xz_offset" 2>/dev/null
      
      # Append the new initramfs
      cat kernel-part initramfs.cpio.xz > new-kernel
      
      echo "Kernel repackaging completed using XZ offset method"
    else
      # Fallback method: try to find gzip signature
      gzip_offset=$(od -t x1 -A d original-kernel | grep '1f 8b 08 00' | head -1 | awk '{print $1}')
      
      if [ -n "$gzip_offset" ]; then
        echo "Found gzip compressed data at offset: $gzip_offset"
        
        # Extract the kernel part (before initramfs)
        dd if=original-kernel of=kernel-part bs=1 count="$gzip_offset" 2>/dev/null
        
        # Append the new initramfs
        cat kernel-part initramfs.cpio.xz > new-kernel
        
        echo "Kernel repackaging completed using gzip offset method"
      else
        echo "WARNING: Could not find initramfs offset in kernel"
        echo "Using fallback method: appending initramfs to end of kernel"
        
        # Fallback: just append the new initramfs to the original kernel
        # This might not work for all ChromeOS devices but it's a reasonable attempt
        cat original-kernel initramfs.cpio.xz > new-kernel
        
        echo "Kernel repackaging completed using fallback method"
      fi
    fi
    
    # Verify the new kernel was created
    if [ ! -f "new-kernel" ]; then
      echo "ERROR: Failed to create repackaged kernel"
      exit 1
    fi
    
    new_kernel_size=$(stat -c%s new-kernel)
    echo "New kernel size: $new_kernel_size bytes"
    echo "Size difference: $((new_kernel_size - kernel_size)) bytes"
    
    # Basic validation: check if the new kernel is larger than the original
    if [ "$new_kernel_size" -le "$kernel_size" ]; then
      echo "WARNING: New kernel is not larger than original - this might indicate a problem"
    else
      echo "New kernel is larger than original - this is expected"
    fi
    
    runHook postBuild
  '';
  
  # Install phase - copy the repackaged kernel
  installPhase = ''
    runHook preInstall
    
    # Copy the repackaged kernel
    mkdir -p $out
    cp new-kernel $out/kernel
    
    # Also copy the compressed initramfs for reference
    cp initramfs.cpio.xz $out/initramfs.cpio.xz
    
    # Create a metadata file with repackaging information
    cat > $out/repackaging-metadata.txt << EOF
Kernel Repackaging Metadata
===========================
Source Kernel: $src
Patched Initramfs: ${patchedInitramfs}
Repackaging Date: $(date)
Original Kernel Size: $kernel_size bytes
New Kernel Size: $new_kernel_size bytes
Size Difference: $((new_kernel_size - kernel_size)) bytes
Initramfs Size: $initramfs_size bytes
Repackaging Method: $([ -n "$xz_offset" ] && echo "XZ offset" || ([ -n "$gzip_offset" ] && echo "Gzip offset" || echo "Fallback append"))

This kernel has been repackaged with a patched initramfs that includes
the shimboot bootloader. The new initramfs will execute bootstrap.sh
during the boot process, allowing for custom boot functionality.

Note: Kernel repackaging is a complex process and the result may need
additional validation and testing on target hardware.
EOF
    
    runHook postInstall
  '';
  
  # Meta information
  meta = with lib; {
    description = "Repackaged ChromeOS kernel with patched initramfs";
    longDescription = ''
      This derivation repackages a ChromeOS kernel with a patched initramfs that
      includes the shimboot bootloader. It extracts the original kernel, creates
      a new initramfs archive from the patched files, and combines them into a
      new kernel image.
      
      The repackaging process attempts to locate the original initramfs within
      the kernel and replace it with the new one. This involves parsing the
      kernel structure and handling compression formats (xz, gzip).
      
      The resulting kernel should boot with the shimboot functionality when
      flashed to appropriate ChromeOS hardware.
    '';
    license = licenses.bsd3;
    platforms = platforms.linux;
    maintainers = [ "shimboot developers" ];
  };
})