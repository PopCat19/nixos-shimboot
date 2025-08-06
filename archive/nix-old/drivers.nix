# ./nix/drivers.nix
{ pkgs, shimFile }:

pkgs.stdenv.mkDerivation {
  name = "chromebook-drivers";
  src = shimFile;

  # Tools needed to perform the extraction.
  nativeBuildInputs = [ pkgs.vboot_reference pkgs.e2fsprogs ];

  # This derivation cannot be built in the normal Nix sandbox because it
  # needs to create loop devices and mount filesystems.
  # You must build it with: nix build .#drivers --option sandbox false
  __impureHostDeps = [ "/dev/loop-control" "/dev/mapper/control" ];

  unpackPhase = ''
    # Don't unpack the source, we just need the path to it.
    cp $src image.bin
  '';

  buildPhase = ''
    set -x
    # Create a loop device for the image.
    loop_device=$(sudo losetup -f --show image.bin)

    # Find the offset and size of partition 3 (ROOT-A).
    # cgpt show returns output like:
    #      start        size    part  contents
    # ...
    #   411648      2097152       3  Label: "ROOT-A"
    # We grab the start and size in sectors (512 bytes).
    part_info=$(cgpt show -n -i 3 $loop_device)
    part_start=$(echo $part_info | cut -d' ' -f1)
    part_size=$(echo $part_info | cut -d' ' -f2)

    # Create a loop device for just the partition.
    sudo losetup -d $loop_device
    part_loop_device=$(sudo losetup -f --show -o $(($part_start * 512)) --sizelimit $(($part_size * 512)) image.bin)

    # Mount the partition.
    mkdir ./shim_rootfs
    sudo mount -o ro $part_loop_device ./shim_rootfs
  '';

  installPhase = ''
    # Copy the required firmware and modules to the output directory.
    mkdir -p $out/lib
    sudo cp -r ./shim_rootfs/lib/firmware $out/lib/
    sudo cp -r ./shim_rootfs/lib/modules $out/lib/
  '';

  # Cleanup phase to unmount and remove loop devices.
  # This runs even if the build fails.
  preFixup = ''
    sudo umount ./shim_rootfs || true
    for dev in $(losetup -a | grep "image.bin" | cut -d':' -f1); do
      sudo losetup -d $dev
    done
  '';
}
