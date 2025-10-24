{
  config,
  pkgs,
  lib,
  userConfig,
  ...
}: {
  # Package Configuration
  environment.systemPackages = with pkgs; [
    # System-wide packages
    # Use default applications from user config
    micro
    git
    btop
    kitty # Terminal emulator
    fastfetch
    hwinfo
    wget
    curl
    xdg-utils
    shared-mime-info
    fuse
    starship
    python313Packages.pip
    gh
    unzip
  ];
}
