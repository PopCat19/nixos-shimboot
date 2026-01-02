# Wallpaper Configuration Module
#
# Purpose: Provide wallpaper support for noctalia-shell with nix-config structure
# Dependencies: wallpaper/ directory
# Related: hyprland.nix, noctalia configuration
#
# This module:
# - Scans wallpaper directory for image files
# - Provides wallpaper support for noctalia-shell
# - Forces inclusion of wallpaper directory in Nix store
{lib, ...}: let
  # Force inclusion of the wallpaper directory into the Nix store, even if empty.
  # This prevents ENOENT during evaluation when the directory exists in the repo
  # but Nix didn't copy it because it had no referenced files.
  wallpaperDir = builtins.path {
    path = ../wallpaper;
    name = "wallpaper";
  };

  entries = builtins.readDir wallpaperDir;

  isImage = name: let
    lower = lib.toLower name;
  in
    lib.hasSuffix ".jpg" lower
    || lib.hasSuffix ".jpeg" lower
    || lib.hasSuffix ".png" lower
    || lib.hasSuffix ".webp" lower
    || lib.hasSuffix ".bmp" lower;

  imageNames =
    lib.filter (n: (entries.${n} or null) == "regular" && isImage n)
    (builtins.attrNames entries);

  images =
    map (n: toString (wallpaperDir + ("/" + n))) imageNames;
in {
  inherit images;
}
