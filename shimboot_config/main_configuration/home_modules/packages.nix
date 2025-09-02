{ pkgs, ... }: {
  home.packages = with pkgs; [
    git
    btop
    micro
  ];
}