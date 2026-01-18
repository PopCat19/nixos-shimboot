# Syncthing Module
#
# Purpose: Configure Syncthing file synchronization service
# Dependencies: None
# Related: services.nix
#
# This module:
# - Enables Syncthing service
# - Configures user and data directories from user-config
# - Opens default firewall ports
{ vars, ... }:
{
  services.syncthing = {
    enable = true;
    openDefaultPorts = true;
    user = vars.username;
    group = "users";
    dataDir = "${vars.directories.home}/.config/syncthing";
    configDir = "${vars.directories.home}/.config/syncthing";
  };
}
