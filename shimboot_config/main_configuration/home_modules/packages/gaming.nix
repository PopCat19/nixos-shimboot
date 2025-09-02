{ pkgs, ... }: {
  home.packages = with pkgs; [
    lutris
    osu-lazer-bin
  ];
}