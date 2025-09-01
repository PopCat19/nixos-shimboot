{ pkgs, ... }: {
  # Home Manager module for user "nixos-user"
  home.stateVersion = "24.11";

  programs.fish.enable = true;

  programs.git = {
    enable = true;
    userName = "nixos-user";
    userEmail = "nixos-user@example.invalid";
  };

  home.packages = with pkgs; [
    git
    btop
    micro
  ];
}