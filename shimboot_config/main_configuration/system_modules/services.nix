{ pkgs, ... }:

{
  # System services
  services = {
    # Storage / Packaging
    flatpak.enable = true;
  };
}