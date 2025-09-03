{ pkgs, ... }: {
  home.packages = with pkgs; [
    eza
    wl-clipboard
    pavucontrol
    playerctl
    localsend
  ];
}