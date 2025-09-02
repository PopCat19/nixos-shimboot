{ pkgs, ... }: {
  home.packages = with pkgs; [
    vesktop
    universal-android-debloater
    android-tools
    scrcpy
    mpv
    audacious
    audacious-plugins
    pureref
    youtube-music
  ];
}