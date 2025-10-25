# Wallpaper Configuration Module
#
# Purpose: Generate hyprpaper configuration for wallpaper management
# Dependencies: wallpaper/ directory
# Related: hyprland.nix, autostart.nix
#
# This module:
# - Scans wallpaper directory for image files
# - Generates hyprpaper.conf with preload and wallpaper settings
# - Forces inclusion of wallpaper directory in Nix store
{
  lib,
  pkgs,
  ...
}: let
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

  hyprpaperText = let
    specificImage = "${wallpaperDir}/kasane_teto_utau_drawn_by_yananami_numata220.jpg";
    preloads = ["preload = ${specificImage}"];
    wallpaperLine = ["wallpaper = , ${specificImage}"];
  in
    lib.concatStringsSep "\n" (preloads ++ wallpaperLine) + "\n";

  hyprpaperConf = pkgs.writeText "hyprpaper.conf" hyprpaperText;
in {
  inherit images hyprpaperText hyprpaperConf;
}
