# Wallpaper Module
#
# Purpose: Soft-clone wallpapers to user directory for Noctalia
# Dependencies: None
# Related: noctalia_config/settings.nix
#
# This module:
# - Creates ~/Pictures/Wallpapers directory
# - Soft-clones wallpapers from NIXOS_CONFIG_DIR (doesn't overwrite existing)
# - Allows users to add custom wallpapers without git tracking
{ config, lib, ... }:
let
  wallpapersDir = "${config.home.homeDirectory}/Pictures/Wallpapers";
  configWallpapers = "${builtins.getEnv "NIXOS_CONFIG_DIR"}/shimboot_config/main_configuration/home/wallpaper";
in
{
  home.activation.cloneWallpapers = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p ${wallpapersDir}
    for file in ${configWallpapers}/*; do
      filename=$(basename "$file")
      if [ ! -e "${wallpapersDir}/$filename" ]; then
        cp -r "$file" "${wallpapersDir}/"
      fi
    done
  '';
}
