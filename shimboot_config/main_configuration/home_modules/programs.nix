{ pkgs, ... }: {
  programs.fish.enable = true;

  programs.git = {
    enable = true;
  };

  # Gaming programs - Steam is not under programs in Home Manager
  # These options are not available in Home Manager, they are system-level
  # steam = {
  #   enable = true;
  #   gamescopeSession.enable = true;
  #   remotePlay.openFirewall = true;
  #   dedicatedServer.openFirewall = true;
  #   localNetworkGameTransfers.openFirewall = true;
  # };
}