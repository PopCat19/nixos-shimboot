{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    git
    btop
    micro
    fastfetch
    fuzzel
  ];
}