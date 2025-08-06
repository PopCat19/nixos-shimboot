{
  description = "Pure shimboot NixOS image builder with local files";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixos-generators }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      
      nixosConfig = ./configuration.nix;
      
      # Board information (for metadata and architecture detection)
      boardInfo = {
        dedede = { arch = "x86_64"; };
      };

      # Local file checker - creates dummy files with helpful errors if missing
      checkLocalFile = path: name: 
        if builtins.pathExists path 
        then path
        else pkgs.writeText "missing-${name}" ''
          ERROR: Missing required file: ${toString path}
          
          Please download the required ${name} file and place it at:
          ${toString path}
          
          For shim files, check: https://cros.download/shims
          For recovery files, check: https://cros.download/recovery
        '';

      # Main shimboot builder using pure VM approach with local files
      buildShimboot = { board ? "dedede", shimPath ? null, recoveryPath ? null }:
        let
          boardData = boardInfo.${board} or (throw "Unsupported board: ${board}. Supported boards: ${builtins.concatStringsSep ", " (builtins.attrNames boardInfo)}");
          
          # Use provided paths or default locations
          shimFile = 
            if shimPath != null then shimPath
            else checkLocalFile ./data/shim.bin "shim";
            
          recoveryFile = 
            if recoveryPath != null then recoveryPath  
            else checkLocalFile ./data/recovery.bin "recovery";
            
          arch = boardData.arch;
          hasRecovery = builtins.pathExists (
            if recoveryPath != null then recoveryPath else ./data/recovery.bin
          );
          
        in
        pkgs.vmTools.runInLinuxVM (
          pkgs.runCommand "shimboot-nixos-${board}" {
            buildInputs = with pkgs; [
              cgpt binwalk util-linux e2fsprogs coreutils
              cpio xz gzip nixos-generators.packages.${system}.nixos-generate
              kbd dosfstools findutils gawk jq gnugrep gnutar
              python3 wget unzip pv lz4 file
            ];
            
            # Mount files as virtual drives
            QEMU_OPTS = 
              if hasRecovery 
              then "-drive file=${shimFile},format=raw,if=virtio,readonly=on -drive file=${recoveryFile},format=raw,if=virtio,readonly=on -m 4096"
              else "-drive file=${shimFile},format=raw,if=virtio,readonly=on -m 4096";
            
            # Required files and metadata
            bootloaderDir = ./bootloader;
            configFile = nixosConfig;
            buildBoard = board;
            buildArch = arch;
            hasRecoveryImage = hasRecovery;
            
          } ''
            set -euo pipefail
            
            print_info() {
              printf ">> \033[1;32m%s\033[0m\n" "$1"
            }
            
            print_debug() {
              printf "   \033[0;36m%s\033[0m\n" "$1"
            }
            
            print_error() {
              printf "!! \033[1;31m%s\033[0m\n" "$1" >&2
            }
            
            print_info "=== Pure VM Shimboot Builder ==="
            print_info "Board: ${board} (${arch})"
            print_info "Shim file: ${shimFile}"
            ${if hasRecovery then ''print_info "Recovery file: ${recoveryFile}"'' else ''print_info "Recovery file: Not provided (reduced driver support)"''}
            
            # Check if files are actually usable (not error placeholders)
            if grep -q "ERROR: Missing required file" ${shimFile} 2>/dev/null; then
              print_error "Shim file is missing! Please download it first."
              cat ${shimFile}
              exit 1
            fi
            
            ${if hasRecovery then ''
            if grep -q "ERROR: Missing required file" ${recoveryFile} 2>/dev/null; then
              print_error "Recovery file is missing but was expected!"
              cat ${recoveryFile}
              exit 1
            fi
            '' else ""}
            
            # Step 1: Generate NixOS base image  
            print_info "Building NixOS base image..."
            nixos-generate -f raw -c $configFile --system x86_64-linux -o nixos-base.img
            print_debug "NixOS base image created: $(ls -lh nixos-base.img)"
            
            # Step 2: Extract kernel from shim
            print_info "Extracting kernel from shim image..."
            
            # Shim is always /dev/vdb, recovery (if present) is /dev/vdc
            device="/dev/vdb"
            if cgpt show -i 2 "$device" 2>/dev/null | grep -q "KERN-A"; then
              print_info "Found KERN-A partition on $device"
              cgpt_output=$(cgpt show -i 2 "$device")
              part_start=$(echo "$cgpt_output" | awk '$4 == "Label:" && $5 == "\"KERN-A\"" {print $1}')
              part_size=$(echo "$cgpt_output" | awk '$4 == "Label:" && $5 == "\"KERN-A\"" {print $2}')
              
              print_debug "Kernel partition: start=$part_start, size=$part_size"
              dd if="$device" of=kernel.bin bs=512 skip="$part_start" count="$part_size" status=progress
            else
              print_error "Could not find KERN-A partition in shim image"
              cgpt show "$device"
              exit 1
            fi
            
            # Step 3: Extract and patch initramfs (architecture-aware)
            print_info "Extracting initramfs from kernel..."
            
            if [ "${arch}" = "aarch64" ]; then
              print_debug "Using ARM64 initramfs extraction method"
              
              # ARM method: find LZ4 compressed data
              binwalk_out="$(binwalk kernel.bin)"
              lz4_offset="$(echo "$binwalk_out" | grep -o '^[0-9]*.*LZ4 compressed data' | head -n1 | cut -d' ' -f1)"
              
              if [ -n "$lz4_offset" ]; then
                print_debug "Found LZ4 data at offset: $lz4_offset"
                dd if=kernel.bin of=kernel.lz4 iflag=skip_bytes,count_bytes skip="$lz4_offset"
                lz4 -d kernel.lz4 kernel_decompressed.bin -q || true
                
                # Extract cpio from decompressed kernel
                binwalk --extract kernel_decompressed.bin > /dev/null || true
                extracted_dir="$(find . -name "_kernel_decompressed.bin.extracted" -type d | head -n 1)"
                
                if [ -n "$extracted_dir" ]; then
                  cpio_file=$(find "$extracted_dir" -name "*" -exec file {} \; | grep "ASCII cpio archive" | cut -d: -f1 | head -n 1)
                  if [ -n "$cpio_file" ]; then
                    mkdir -p initramfs_work
                    cat "$cpio_file" | (cd initramfs_work && cpio -id --quiet) || true
                  fi
                fi
              fi
              
            else
              print_debug "Using x86_64 initramfs extraction method"
              
              # x86_64 method: gzip then XZ extraction
              binwalk -y gzip -l /tmp/binwalk_log kernel.bin || true
              if [ -f /tmp/binwalk_log ]; then
                offset=$(grep '"offset"' /tmp/binwalk_log | awk -F': ' '{print $2}' | sed 's/,//' | head -n 1)
                if [ -n "$offset" ]; then
                  print_debug "Found gzip data at offset: $offset"
                  dd if=kernel.bin bs=1 skip="$offset" | zcat > decompressed_kernel.bin || true
                  
                  # Find XZ compressed cpio
                  binwalk -l /tmp/binwalk_log2 decompressed_kernel.bin || true
                  if [ -f /tmp/binwalk_log2 ]; then
                    xz_offset=$(cat /tmp/binwalk_log2 | jq -r '.[0].Analysis.file_map[]? | select(.description | contains("XZ compressed data")) | .offset' | head -n 1)
                    if [ -n "$xz_offset" ] && [ "$xz_offset" != "null" ]; then
                      print_debug "Found XZ data at offset: $xz_offset"
                      mkdir -p initramfs_work
                      dd if=decompressed_kernel.bin bs=1 skip="$xz_offset" | xz -d | (cd initramfs_work && cpio -id --quiet) || true
                    fi
                  fi
                fi
              fi
            fi
            
            # Fallback: try generic binwalk extraction
            if [ ! -d "initramfs_work" ] || [ -z "$(ls -A initramfs_work 2>/dev/null)" ]; then
              print_debug "Fallback: trying generic binwalk extraction"
              binwalk --extract kernel.bin > /dev/null || true
              
              # Look for any extracted cpio archives
              for extracted_dir in $(find . -name "_kernel*.extracted" -type d); do
                cpio_file=$(find "$extracted_dir" -name "*.cpio" -o -name "*" -exec file {} \; | grep "ASCII cpio archive" | cut -d: -f1 | head -n 1)
                if [ -n "$cpio_file" ]; then
                  mkdir -p initramfs_work 
                  cd initramfs_work
                  cpio -id --quiet < "../$cpio_file" || true
                  cd ..
                  break
                fi
              done
            fi
            
            if [ ! -d "initramfs_work" ] || [ -z "$(ls -A initramfs_work 2>/dev/null)" ]; then
              print_error "Failed to extract initramfs from kernel!"
              print_debug "Available files:"
              ls -la
              print_debug "Binwalk output:"
              binwalk kernel.bin || true
              exit 1
            fi
            
            print_debug "Successfully extracted initramfs: $(ls initramfs_work | wc -l) files"
            
            # Patch the initramfs with bootloader
            print_info "Patching initramfs with shimboot bootloader..."
            cp -r $bootloaderDir/* initramfs_work/
            echo 'exec /bin/bootstrap.sh' >> initramfs_work/init
            find initramfs_work/bin -type f -exec chmod +x {} \;
            print_debug "Bootloader integration complete"
            
            # Step 4: Harvest drivers and firmware
            print_info "Harvesting drivers and firmware..."
            mkdir -p harvested_modules harvested_firmware harvested_modprobe
            
            # Process shim image (always /dev/vdb)
            devices_to_process="/dev/vdb"
            ${if hasRecovery then ''devices_to_process="$devices_to_process /dev/vdc"'' else ""}
            
            for device in $devices_to_process; do
              device_name=$([ "$device" = "/dev/vdb" ] && echo "shim" || echo "recovery")
              print_debug "Processing $device_name image ($device)"
              
              # Find the rootfs partition (usually ROOT-A = partition 3)
              rootfs_part=""
              for part_num in 3 4 5; do
                if [ -b "${device}p${part_num}" ]; then
                  part_info=$(cgpt show -i $part_num "$device" 2>/dev/null || true)
                  if echo "$part_info" | grep -q "ROOT-A\|ChromeOS\|rootfs"; then
                    rootfs_part="${device}p${part_num}"
                    break
                  fi
                fi
              done
              
              if [ -n "$rootfs_part" ] && [ -b "$rootfs_part" ]; then
                print_debug "Mounting $device_name rootfs: $rootfs_part"
                mkdir -p "/tmp/mount_$device_name"
                if mount -o ro "$rootfs_part" "/tmp/mount_$device_name" 2>/dev/null; then
                  
                  # Harvest kernel modules
                  if [ -d "/tmp/mount_$device_name/lib/modules" ]; then
                    cp -ar "/tmp/mount_$device_name/lib/modules"/* harvested_modules/ 2>/dev/null || true
                    module_count=$(find harvested_modules -name "*.ko*" 2>/dev/null | wc -l)
                    print_debug "Harvested $module_count modules from $device_name"
                  fi
                  
                  # Harvest firmware
                  if [ -d "/tmp/mount_$device_name/lib/firmware" ]; then
                    cp -ar "/tmp/mount_$device_name/lib/firmware"/* harvested_firmware/ 2>/dev/null || true
                    firmware_count=$(find harvested_firmware -type f 2>/dev/null | wc -l)
                    print_debug "Harvested $firmware_count firmware files from $device_name"
                  fi
                  
                  # Harvest modprobe configs (mainly from recovery)
                  if [ -d "/tmp/mount_$device_name/lib/modprobe.d" ]; then
                    cp -ar "/tmp/mount_$device_name/lib/modprobe.d"/* harvested_modprobe/ 2>/dev/null || true
                  fi
                  if [ -d "/tmp/mount_$device_name/etc/modprobe.d" ]; then
                    cp -ar "/tmp/mount_$device_name/etc/modprobe.d"/* harvested_modprobe/ 2>/dev/null || true
                  fi
                  
                  umount "/tmp/mount_$device_name"
                else
                  print_debug "Failed to mount $device_name rootfs"
                fi
              else
                print_debug "No suitable rootfs partition found on $device_name"
                # Show what partitions exist for debugging
                cgpt show "$device" 2>/dev/null || true
              fi
            done
            
            # Step 5: Mount NixOS base image
            print_info "Setting up NixOS base image..."
            losetup -P /dev/loop0 nixos-base.img
            mkdir -p nixos_rootfs
            
            # Find the NixOS rootfs partition
            nixos_part="/dev/loop0p1"
            if [ ! -b "$nixos_part" ]; then
              for part_num in 2 3 4; do
                if [ -b "/dev/loop0p$part_num" ]; then
                  nixos_part="/dev/loop0p$part_num"
                  break
                fi
              done
            fi
            
            mount -o ro "$nixos_part" nixos_rootfs
            
            # Step 6: Calculate sizes and create final image
            print_info "Creating final shimboot disk image..."
            nixos_size_kb=$(du -s nixos_rootfs | cut -f1)
            nixos_size_mb=$((nixos_size_kb / 1024))
            rootfs_size_mb=$((nixos_size_mb * 13 / 10 + 500))  # 30% overhead + 500MB
            total_size_mb=$((1 + 32 + 32 + rootfs_size_mb))
            
            print_debug "NixOS size: ''${nixos_size_mb}MB"
            print_debug "Final rootfs partition: ''${rootfs_size_mb}MB" 
            print_debug "Total image size: ''${total_size_mb}MB"
            
            fallocate -l "''${total_size_mb}M" final_image.bin
            
            # Create ChromeOS-style partition table
            (
              echo g      # GPT partition table
              echo n; echo; echo; echo +1M     # STATE partition (1MB)
              echo n; echo; echo; echo +32M    # KERN-A partition (32MB)
              echo n; echo; echo; echo +32M    # BOOT partition (32MB) 
              echo n; echo; echo; echo         # ROOT partition (remaining space)
              echo w      # Write changes
            ) | fdisk final_image.bin > /dev/null
            
            # Set ChromeOS-specific partition labels and flags
            cgpt add -i 1 -t data -l "STATE" final_image.bin
            cgpt add -i 2 -t kernel -l "KERN-A" -S 1 -T 5 -P 10 final_image.bin
            cgpt add -i 3 -t rootfs -l "BOOT" final_image.bin
            cgpt add -i 4 -t data -l "shimboot_rootfs:nixos" final_image.bin
            
            # Set up loop device for final image
            losetup -P /dev/loop1 final_image.bin
            
            # Format all partitions
            print_info "Formatting partitions..."
            mkfs.ext4 -L STATE /dev/loop1p1 > /dev/null
            dd if=kernel.bin of=/dev/loop1p2 bs=1M oflag=sync status=progress
            mkfs.ext2 -L BOOT /dev/loop1p3 > /dev/null
            mkfs.ext4 -L ROOTFS -O ^has_journal,^extent,^huge_file,^flex_bg,^metadata_csum,^64bit,^dir_nlink /dev/loop1p4 > /dev/null
            
            # Step 7: Populate all partitions
            print_info "Populating disk image..."
            
            # STATE partition (minimal ChromeOS stateful)
            mkdir -p state_mount
            mount /dev/loop1p1 state_mount
            mkdir -p state_mount/dev_image/etc state_mount/dev_image/factory/sh
            touch state_mount/dev_image/etc/lsb-factory
            umount state_mount
            
            # BOOT partition (shimboot bootloader)
            mkdir -p boot_mount  
            mount /dev/loop1p3 boot_mount
            cp -ar initramfs_work/* boot_mount/
            umount boot_mount
            
            # ROOT partition (NixOS + harvested drivers)
            mkdir -p root_mount
            mount /dev/loop1p4 root_mount
            
            # Copy NixOS rootfs with progress
            print_info "Copying NixOS rootfs..."
            rootfs_bytes=$(du -sb nixos_rootfs | cut -f1)
            tar -cf - -C nixos_rootfs . | pv -s "$rootfs_bytes" | tar -xf - -C root_mount
            
            # Inject harvested components
            print_info "Installing harvested drivers and firmware..."
            
            # Install kernel modules
            if [ -d "harvested_modules" ] && [ "$(ls -A harvested_modules 2>/dev/null)" ]; then
              mkdir -p root_mount/lib/modules
              cp -ar harvested_modules/* root_mount/lib/modules/
              
              # Decompress modules (ChromeOS compresses them, NixOS expects uncompressed)
              compressed_modules=$(find root_mount/lib/modules -name "*.gz" 2>/dev/null || true)
              if [ -n "$compressed_modules" ]; then
                print_debug "Decompressing $(echo "$compressed_modules" | wc -l) kernel modules..."
                echo "$compressed_modules" | xargs gunzip
                
                # Rebuild module dependency database
                for kdir in root_mount/lib/modules/*; do
                  if [ -d "$kdir" ]; then
                    kver=$(basename "$kdir")
                    print_debug "Rebuilding dependencies for kernel $kver"
                    chroot root_mount depmod "$kver" 2>/dev/null || true
                  fi
                done
              fi
              print_debug "Kernel modules installed and configured"
            else
              print_debug "No kernel modules harvested"
            fi
            
            # Install firmware
            if [ -d "harvested_firmware" ] && [ "$(ls -A harvested_firmware 2>/dev/null)" ]; then
              mkdir -p root_mount/lib/firmware
              cp -ar harvested_firmware/* root_mount/lib/firmware/
              firmware_count=$(find root_mount/lib/firmware -type f | wc -l)
              print_debug "Installed $firmware_count firmware files"
            else
              print_debug "No firmware harvested"  
            fi
            
            # Install modprobe configurations
            if [ -d "harvested_modprobe" ] && [ "$(ls -A harvested_modprobe 2>/dev/null)" ]; then
              mkdir -p root_mount/lib/modprobe.d root_mount/etc/modprobe.d
              cp -ar harvested_modprobe/* root_mount/lib/modprobe.d/ 2>/dev/null || true
              cp -ar harvested_modprobe/* root_mount/etc/modprobe.d/ 2>/dev/null || true
              config_count=$(find root_mount/lib/modprobe.d root_mount/etc/modprobe.d -name "*.conf" 2>/dev/null | wc -l)
              print_debug "Installed $config_count modprobe configuration files"
            else
              print_debug "No modprobe configurations harvested"
            fi
            
            # Step 8: Configure init system
            print_info "Configuring init system..."
            
            # Find systemd binary in Nix store
            systemd_path=$(find root_mount/nix/store -path "*/lib/systemd/systemd" -type f | head -n 1)
            if [ -z "$systemd_path" ]; then
              systemd_path=$(find root_mount/nix/store -path "*/bin/systemd" -type f | head -n 1)
            fi
            
            if [ -n "$systemd_path" ]; then
              symlink_target=''${systemd_path#root_mount}
              ln -sf "$symlink_target" root_mount/init
              print_debug "Created /init -> $symlink_target"
              
              # Create traditional init symlinks for compatibility
              mkdir -p root_mount/sbin root_mount/usr/sbin
              ln -sf /init root_mount/sbin/init
              ln -sf /init root_mount/usr/sbin/init
              print_debug "Created traditional init symlinks"
            else
              print_error "Could not find systemd binary in Nix store!"
              ls -la root_mount/nix/store/ | head -20
              exit 1
            fi
            
            # Reset machine-id for clean first boot
            rm -f root_mount/etc/machine-id
            touch root_mount/etc/machine-id
            print_debug "Reset machine-id for first boot"
            
            # Step 9: Finalize and cleanup
            print_info "Finalizing image..."
            
            # Unmount everything
            umount root_mount nixos_rootfs
            losetup -d /dev/loop0 /dev/loop1
            
            # Create output
            mkdir -p $out
            cp final_image.bin $out/shimboot_nixos_${board}.bin
            
            # Generate build metadata
            cat > $out/build-info.json << EOF
            {
              "board": "${board}",
              "arch": "${arch}",
              "has_recovery": ${if hasRecovery then "true" else "false"},
              "build_date": "$(date -Iseconds)",
              "image_size_mb": $total_size_mb,
              "nixos_config": "$(basename $configFile)",
              "shim_source": "${shimFile}",
              "recovery_source": ${if hasRecovery then "\"${recoveryFile}\"" else "null"}
            }
            EOF
            
            # Generate usage instructions
            cat > $out/README.txt << EOF
            Shimboot NixOS Image for ${board}
            =====================================
            
            Board: ${board} (${arch})
            Built: $(date)
            Recovery drivers: ${if hasRecovery then "Yes" else "No"}
            
            To flash this image:
            1. Use Chromebook Recovery Utility, or
            2. Use dd: sudo dd if=shimboot_nixos_${board}.bin of=/dev/sdX bs=4M status=progress
            
            Default login: user/user
            
            After first boot, run: sudo expand_rootfs
            EOF
            
            print_info "=== Build Complete! ==="
            print_info "Board: ${board}"
            print_info "Output: $out/shimboot_nixos_${board}.bin"
            print_info "Size: $(ls -lh $out/shimboot_nixos_${board}.bin | awk '{print $5}')"
            ${if hasRecovery then ''print_info "✓ Built with recovery image drivers"'' else ''print_info "⚠ Built without recovery image - reduced driver support"''}
          ''
        );

    in {
      packages.${system} = {
        # Default builds using files in ./data/
        default = buildShimboot { board = "dedede"; };
        dedede = buildShimboot { board = "dedede"; };
        
        # Example of custom file paths
        # dedede-custom = buildShimboot { 
        #   board = "dedede"; 
        #   shimPath = /path/to/custom/shim.bin;
        #   recoveryPath = /path/to/custom/recovery.bin;
        # };
      };
      
      # Expose builder function for custom usage
      lib = {
        buildShimboot = buildShimboot;
        supportedBoards = builtins.attrNames boardInfo;
      };
      
      # Helper applications
      apps.${system} = {
        list-boards = {
          type = "app";
          program = "${pkgs.writeShellScript "list-boards" ''
            echo "Supported boards:"
            ${builtins.concatStringsSep "\n" (map (board: "echo '  ${board} (${boardInfo.${board}.arch})'") (builtins.attrNames boardInfo))}
            echo ""
            echo "Files expected:"
            echo "  ./data/shim.bin     - ChromeOS RMA shim for your board"
            echo "  ./data/recovery.bin - ChromeOS recovery image (optional but recommended)"
          ''}";
        };
        
        check-files = {
          type = "app";
          program = "${pkgs.writeShellScript "check-files" ''
            echo "Checking for required files..."
            
            if [ -f "./data/shim.bin" ]; then
              size=$(ls -lh ./data/shim.bin | awk '{print $5}')
              echo "✓ shim.bin found ($size)"
            else
              echo "✗ shim.bin missing (./data/shim.bin)"
            fi
            
            if [ -f "./data/recovery.bin" ]; then
              size=$(ls -lh ./data/recovery.bin | awk '{print $5}')
              echo "✓ recovery.bin found ($size)"
            else  
              echo "⚠ recovery.bin missing - will build with reduced driver support"
            fi
            
            if [ -d "./bootloader" ]; then
              echo "✓ bootloader directory found"
            else
              echo "✗ bootloader directory missing"
            fi
            
            if [ -f "./configuration.nix" ]; then
              echo "✓ configuration.nix found"
            else
              echo "✗ configuration.nix missing"
            fi
          ''}";
        };
      };
    };
}
