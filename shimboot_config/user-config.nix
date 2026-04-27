# user-config.nix
#
# Purpose: Global user configuration for nixos-shimboot
#
# This module:
# - Defines host and board configuration
# - Defines user credentials and groups
# - Defines default application preferences
# - Defines system directory structure
#
# Board configuration:
# - Required: board must be set for hardware-specific drivers
# - Default: "dedede" for backward compatibility with direct builds
# - Consumer configs should override this
{
  hostname ? "nixos-shimboot",
  system ? "x86_64-linux",
  username ? "nixos-user",
  board ? "dedede", # Default for direct builds; consumers should override
}:
{
  host = {
    inherit system;
    inherit hostname;
    inherit board; # Board identifier for hardware config
  };

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

    clipboard = {
      command = "bash -lc \"cliphist list | fuzzel --dmenu --with-nth 2 | cliphist decode | wl-copy && sleep 0.05 && wtype -M ctrl -k v\"";
    };
  };

  timezone = "America/New_York";
  locale = "en_US.UTF-8";

  directories =
    let
      home = "/home/${username}";
    in
    {
      inherit home;
      documents = "${home}/Documents";
      downloads = "${home}/Downloads";
      pictures = "${home}/Pictures";
      videos = "${home}/Videos";
      music = "${home}/Music";
      desktop = "${home}/Desktop";
    };

  env =
    let
      repoName = "nixos-shimboot";
    in
    {
      inherit repoName;
      NIXOS_CONFIG_DIR = "${directories.home}/${repoName}";
    };
}
