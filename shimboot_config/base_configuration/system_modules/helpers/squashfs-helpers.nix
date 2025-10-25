# SquashFS Helpers Configuration Module
#
# Purpose: Provide post-install compression tools for /nix/store
# Dependencies: squashfs-tools, systemd
# Related: filesystems.nix, packages.nix
#
# This module provides:
# - compress-nix-store: One-way compression of /nix/store to save ~50% space
# - uncompress-nix-store: Restore compressed /nix/store back to normal
# - User-friendly interactive scripts with safety checks
# - Automatic fstab management for squashfs mounting

{
  config,
  pkgs,
  lib,
  ...
}: {
  environment.systemPackages = with pkgs; [
    squashfsTools
    
    (writeShellScriptBin "compress-nix-store" ''
      #!/usr/bin/env bash
      # Compress /nix/store to save ~50% space
      # WARNING: This is a ONE-WAY operation. Backup first!
      
      set -e
      
      if [ "$EUID" -ne 0 ]; then
        echo "This script must be run as root"
        exit 1
      fi
      
      if [ -f "/nix/.ro-store/store.squashfs" ]; then
        echo "⚠️  /nix/store is already compressed!"
        echo "To uncompress: sudo uncompress-nix-store"
        exit 1
      fi
      
      echo "🗜️  This will compress /nix/store using squashfs"
      echo "   Expected space savings: ~50%"
      echo "   /nix/store will become READ-ONLY"
      echo ""
      read -p "Continue? [y/N] " confirm
      if [ "$confirm" != "y" ]; then
        echo "Aborted"
        exit 0
      fi
      
      STORE_SIZE=$(du -sm /nix/store | cut -f1)
      echo "📊 Original /nix/store size: ''${STORE_SIZE} MB"
      
      echo "📦 Creating squashfs (this may take several minutes)..."
      mkdir -p /nix/.ro-store
      mksquashfs /nix/store /nix/.ro-store/store.squashfs \
        -comp zstd \
        -Xcompression-level 15 \
        -noappend
      
      SQUASH_SIZE=$(du -sm /nix/.ro-store/store.squashfs | cut -f1)
      SAVED=$((STORE_SIZE - SQUASH_SIZE))
      PERCENT=$((SAVED * 100 / STORE_SIZE))
      
      echo "✓ squashfs created: ''${SQUASH_SIZE} MB (saved ''${SAVED} MB, ''${PERCENT}%)"
      
      # Add fstab entry
      if ! grep -q "/nix/store.*squashfs" /etc/fstab 2>/dev/null; then
        echo "📝 Adding /etc/fstab entry..."
        echo "/nix/.ro-store/store.squashfs /nix/store squashfs ro,loop 0 0" >> /etc/fstab
      fi
      
      echo ""
      echo "⚠️  IMPORTANT: Reboot required to activate compressed store"
      echo ""
      echo "After reboot:"
      echo "  • /nix/store will be read-only"
      echo "  • Use 'nix-shell -p <package>' for temporary packages"
      echo "  • To add permanent packages, edit configuration.nix and rebuild"
      echo ""
      read -p "Reboot now? [y/N] " reboot_confirm
      if [ "$reboot_confirm" = "y" ]; then
        reboot
      fi
    '')
    
    (writeShellScriptBin "uncompress-nix-store" ''
      #!/usr/bin/env bash
      # Uncompress /nix/store back to normal
      
      set -e
      
      if [ "$EUID" -ne 0 ]; then
        echo "This script must be run as root"
        exit 1
      fi
      
      if [ ! -f "/nix/.ro-store/store.squashfs" ]; then
        echo "⚠️  /nix/store is not compressed"
        exit 1
      fi
      
      if mountpoint -q /nix/store; then
        echo "⚠️  /nix/store is currently mounted"
        echo "   Reboot into a live environment to uncompress"
        exit 1
      fi
      
      echo "🗜️  This will uncompress /nix/store"
      echo "   You need enough free space for the uncompressed store"
      echo ""
      read -p "Continue? [y/N] " confirm
      if [ "$confirm" != "y" ]; then
        echo "Aborted"
        exit 0
      fi
      
      echo "📦 Extracting squashfs..."
      mkdir -p /nix/store.tmp
      unsquashfs -f -d /nix/store.tmp /nix/.ro-store/store.squashfs
      
      echo "🔄 Replacing compressed store..."
      rm -rf /nix/store
      mv /nix/store.tmp /nix/store
      rm -rf /nix/.ro-store
      
      # Remove fstab entry
      sed -i '\#/nix/store.*squashfs#d' /etc/fstab
      
      echo "✓ /nix/store uncompressed"
      echo "Reboot recommended"
    '')
  ];
}