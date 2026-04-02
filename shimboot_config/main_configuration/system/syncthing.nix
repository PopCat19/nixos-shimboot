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
{ userConfig, ... }:
{
  services.syncthing = {
    enable = true;
    openDefaultPorts = true;
    user = userConfig.user.username;
    group = "users";
    dataDir = "${userConfig.directories.home}/.config/syncthing";
    configDir = "${userConfig.directories.home}/.config/syncthing";
  };
}
