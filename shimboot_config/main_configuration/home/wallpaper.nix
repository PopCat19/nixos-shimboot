# Wallpaper Module
#
# Purpose: Soft-clone wallpapers to user directory for Noctalia
# Dependencies: None
# Related: noctalia_config/settings.nix
#
# This module:
# - Creates ~/Pictures/Wallpapers directory
# - Soft-clones wallpapers from config (doesn't overwrite existing)
# - Allows users to add custom wallpapers without git tracking
{ config, lib, ... }:
let
  wallpapersDir = "${config.home.homeDirectory}/Pictures/Wallpapers";
in
{
  home.activation.cloneWallpapers = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p ${wallpapersDir}
    for file in ${./wallpaper}/*; do
      filename=$(basename "$file")
      if [ ! -e "${wallpapersDir}/$filename" ]; then
        cp -r "$file" "${wallpapersDir}/"
      fi
    done
  '';
}
