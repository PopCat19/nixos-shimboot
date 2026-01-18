# User Configuration Variables
#
# Purpose: Centralized user and system configuration variables
# Dependencies: None (pure configuration)
# Related: lib/default.nix, flake.nix
#
# This file:
# - Defines user credentials and groups
# - Defines host and system configuration
# - Defines default application preferences
# - Defines system directory structure
# - Defines theme and localization settings
{
  # User credentials
  username = "nixos-user";

  # System configuration
  system = "x86_64-linux";

  # Host configuration
  host = {
    hostname = "shimboot";
  };

  # User configuration
  user = {
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
  directories = {
    home = "/home/nixos-user";
    documents = "/home/nixos-user/Documents";
    downloads = "/home/nixos-user/Downloads";
    pictures = "/home/nixos-user/Pictures";
    videos = "/home/nixos-user/Videos";
    music = "/home/nixos-user/Music";
    desktop = "/home/nixos-user/Desktop";
  };

  # Theme configuration for PMD
  theme = {
    hue = 30;
    variant = "dark";
  };
}
