# User Configuration Module
#
# Purpose: Global user configuration for nixos-shimboot
# Dependencies: None (pure configuration)
# Related: base_configuration/configuration.nix, flake.nix
#
# This module defines:
# - Host and system configuration
# - User credentials and groups
# - Default application preferences
# - System directory structure
{
  hostname ? null,
  system ? "x86_64-linux",
  username ? "nixos-user",
}: rec {
  # Host configuration
  host = {
    inherit system;
    hostname =
      if hostname == null
      then username
      else hostname;
  };

  # User credentials
  user = {
    inherit username;
    initialPassword = "nixos-shimboot";
    shellPackage = "fish";

    extraGroups = [
      "wheel"
      "video"
      "audio"
      "networkmanager"
      "i2c"
      "input"
      "libvirtd"
    ];
  };

  # Default applications
  defaultApps = {
    browser = {
      desktop = "zen-twilight.desktop";
      package = "zen-browser";
      command = "zen-twilight";
    };

    terminal = {
      desktop = "kitty.desktop";
      package = "kitty";
      command = "kitty";
    };

    editor = {
      desktop = "micro.desktop";
      package = "micro";
      command = "micro";
    };

    fileManager = {
      desktop = "org.kde.dolphin.desktop";
      package = "kdePackages.dolphin";
      command = "dolphin";
    };

    imageViewer = {
      desktop = "org.kde.gwenview.desktop";
      package = "kdePackages.gwenview";
    };

    videoPlayer = {
      desktop = "mpv.desktop";
      package = "mpv";
    };

    archiveManager = {
      desktop = "org.kde.ark.desktop";
      package = "kdePackages.ark";
    };

    pdfViewer = {
      desktop = "zen-twilight.desktop";
      package = "zen-browser";
    };

    launcher = {
      package = "fuzzel";
      command = "fuzzel";
    };
  };

  # Localization settings
  timezone = "America/New_York";
  locale = "en_US.UTF-8";

  # System directories
  directories = let
    home = "/home/${username}";
  in {
    inherit home;
    documents = "${home}/Documents";
    downloads = "${home}/Downloads";
    pictures = "${home}/Pictures";
    videos = "${home}/Videos";
    music = "${home}/Music";
    desktop = "${home}/Desktop";
  };
}
