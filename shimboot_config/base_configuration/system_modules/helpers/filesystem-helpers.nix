{
  config,
  pkgs,
  lib,
  userConfig,
  ...
}: {
  # Helper shell scripts packaged as binaries
  environment.systemPackages = with pkgs; [
    (writeShellScriptBin "expand_rootfs" ''      # Script to expand the root filesystem
           # NixOS equivalent of shimboot's expand_rootfs script
           set -e
           if [ "$DEBUG" ]; then
             set -x
           fi

           if [ "$EUID" -ne 0 ]; then
             echo "This needs to be run as root."
             exit 1
           fi

           root_dev="$(findmnt -T / -no SOURCE)"
           luks="$(echo "$root_dev" | grep "/dev/mapper" || true)"

           if [ "$luks" ]; then
             echo "Note: Root partition is encrypted."
             kname_dev="$(lsblk --list --noheadings --paths --output KNAME "$root_dev")"
             kname="$(basename "$kname_dev")"
             part_dev="/dev/$(basename "/sys/class/block/$kname/slaves/"*)"
           else
             part_dev="$root_dev"
           fi

           disk_dev="$(lsblk --list --noheadings --paths --output PKNAME "$part_dev" | head -n1)"
           part_num="$(echo "''${part_dev#$disk_dev}" | tr -d 'p')"

           # Check if already expanded
           disk_size=$(blockdev --getsize64 "$disk_dev")
           part_size=$(blockdev --getsize64 "$part_dev")
           if [ "$part_size" -ge "$disk_size" ]; then
             echo "Root partition already uses the full disk space. Nothing to do."
             exit 0
           fi

           echo "Automatically detected root filesystem:"
           fdisk -l "$disk_dev" 2>/dev/null | grep "''${disk_dev}:" -A 1
           echo
           echo "Automatically detected root partition:"
           fdisk -l "$disk_dev" 2>/dev/null | grep "''${part_dev}"
           echo
           read -p "Press enter to continue, or ctrl+c to cancel. "

           echo
           echo "Before:"
           df -h /

           echo
           echo "Expanding the partition and filesystem..."
           ${cloud-utils}/bin/growpart "$disk_dev" "$part_num" || true
           if [ "$luks" ]; then
             /bootloader/bin/cryptsetup resize "$root_dev" || true
           fi
           ${e2fsprogs}/bin/resize2fs "$root_dev" || true

           echo
           echo "After:"
           df -h /

           echo
           echo "Done expanding the root filesystem."
    '')
  ];
}
