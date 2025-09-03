{ pkgs, ... }: {
  home.packages = with pkgs; [
    mpv
    audacious
    audacious-plugins
    pureref
    youtube-music
  ];
}