{ pkgs, ... }: {
  programs.fish.enable = true;

  programs.git = {
    enable = true;
  };

  # Gaming programs
  gamemode.enable = true;
  steam = {
    enable = true;
    gamescopeSession.enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
  };
}