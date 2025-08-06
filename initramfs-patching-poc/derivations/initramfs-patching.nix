{ stdenv, lib, fetchurl, coreutils, bootloaderFiles, extractedInitramfs }:

stdenv.mkDerivation (finalAttrs: {
  pname = "patched-initramfs";
  version = "1.0.0";
  
  # The source is the extracted initramfs from the previous derivation
  src = extractedInitramfs;
  
  # Native build dependencies
  nativeBuildInputs = [
    coreutils     # For cp, chmod, etc.
  ];
  
  # Don't need to unpack since we're processing a directory structure
  dontUnpack = true;
  
  # Don't need to fix up since we're just patching files
  dontFixup = true;
  
  # Build phase - patch the initramfs with bootloader files
  buildPhase = ''
    runHook preBuild
    
    echo "Patching initramfs with shimboot bootloader..."
    
    # Verify that the extracted initramfs exists
    if [ ! -d "$src" ]; then
      echo "ERROR: Extracted initramfs directory not found: $src"
      exit 1
    fi
    
    # Verify that bootloader files exist
    if [ ! -d "${bootloaderFiles}" ]; then
      echo "ERROR: Bootloader files directory not found: ${bootloaderFiles}"
      exit 1
    fi
    
    # Copy the entire initramfs to build directory
    cp -r "$src" initramfs-patched
    cd initramfs-patched
    
    # Backup the original init script
    if [ -f "init" ]; then
      cp init init.backup
      echo "Original init script backed up to init.backup"
    else
      echo "ERROR: Init script not found in extracted initramfs"
      exit 1
    fi
    
    # Copy bootloader files to initramfs
    echo "Copying bootloader files to initramfs..."
    if ! cp -rT "${bootloaderFiles}" .; then
      echo "ERROR: Failed to copy bootloader files"
      exit 1
    fi
    
    # Patch the init script to execute bootstrap.sh
    echo "Patching init script to execute shimboot bootloader..."
    
    # Create new init script content
    cat > init << 'EOF'
#!/bin/busybox sh
# Copyright 2015 The Chromium OS Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#
# /init script for use in factory install shim.
# Note that this script uses the busybox shell (not bash, not dash).
set -x

. /lib/init.sh

setup_environment() {
  initialize

  # Install additional utility programs.
  /bin/busybox --install /bin || true
}

main() {
  setup_environment
  # In case an error is not handled by bootstrapping, stop here
  # so that an operator can see installation stop.
  exec /bin/bootstrap.sh || sleep 1d
}

# Make this source-able for testing.
if [ "$0" = "/init" ]; then
  main "$@"
  # Should never reach here.
  exit 1
fi
EOF
    
    # Make bootloader scripts executable
    echo "Making bootloader scripts executable..."
    find bin -type f -exec chmod +x {} \;
    chmod +x bin/bootstrap.sh
    chmod +x bin/init
    
    # Verify the patching
    echo "Verifying initramfs patching..."
    
    # Check if bootloader files exist
    if [ ! -f "bin/bootstrap.sh" ]; then
      echo "ERROR: Required bootloader file not found: bin/bootstrap.sh"
      exit 1
    fi
    
    if [ ! -f "bin/init" ]; then
      echo "ERROR: Required bootloader file not found: bin/init"
      exit 1
    fi
    
    if [ ! -f "opt/crossystem" ]; then
      echo "ERROR: Required bootloader file not found: opt/crossystem"
      exit 1
    fi
    
    if [ ! -f "opt/mount-encrypted" ]; then
      echo "ERROR: Required bootloader file not found: opt/mount-encrypted"
      exit 1
    fi
    
    if [ ! -f "opt/.shimboot_version" ]; then
      echo "ERROR: Required bootloader file not found: opt/.shimboot_version"
      exit 1
    fi
    
    # Check if init script contains bootstrap.sh
    if ! grep -q "bootstrap.sh" init; then
      echo "ERROR: Init script does not contain bootstrap.sh execution"
      exit 1
    fi
    
    # Check if files are executable
    if [ ! -x "bin/bootstrap.sh" ]; then
      echo "ERROR: bootstrap.sh is not executable"
      exit 1
    fi
    
    if [ ! -x "bin/init" ]; then
      echo "ERROR: init is not executable"
      exit 1
    fi
    
    echo "Initramfs patching verification passed"
    echo "Patched initramfs available at: $(pwd)"
    
    runHook postBuild
  '';
  
  # Install phase - copy the patched initramfs to the output directory
  installPhase = ''
    runHook preInstall
    
    # Copy the entire patched initramfs directory structure
    cp -r initramfs-patched $out/
    
    # Create a metadata file with patching information
    cat > $out/patching-metadata.txt << EOF
Initramfs Patching Metadata
==========================
Source Initramfs: $src
Bootloader Files: ${bootloaderFiles}
Patching Date: $(date)
Patching Method: File copy + init script modification
Bootstrap Integration: Complete
Executable Permissions: Set
EOF
    
    # Copy the original init script backup for reference
    if [ -f "initramfs-patched/init.backup" ]; then
      cp initramfs-patched/init.backup $out/init.backup
    fi
    
    runHook postInstall
  '';
  
  # Meta information
  meta = with lib; {
    description = "Patched ChromeOS initramfs with shimboot bootloader";
    longDescription = ''
      This derivation patches a ChromeOS initramfs with shimboot bootloader files.
      It copies the bootloader files into the initramfs directory structure and modifies
      the init script to execute the shimboot bootstrap process. The patched initramfs
      is ready for integration into a NixOS build system.
    '';
    license = licenses.bsd3;
    platforms = platforms.linux;
    maintainers = [ "shimboot developers" ];
  };
})