{ pkgs, ... }: {
  programs.fish.enable = true;

  programs.git = {
    enable = true;
    userName = "nixos-user";
    userEmail = "nixos-user@example.invalid";
  };
}