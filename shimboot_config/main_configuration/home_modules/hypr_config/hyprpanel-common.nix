# hyprpanel-common.nix
# HyprPanel common configuration with Rose Pine theme integration
# This contains all shared settings except bar.layouts which are host-specific
# Based on documentation: https://hyprpanel.com/
{ ... }:
{
  # HyprPanel is available in nixpkgs and has a home-manager module
  # No need for separate flake input - just enable the program
  programs.hyprpanel = {

    # Enable the module.
    # Default: false
    enable = true;

    # Automatically restart HyprPanel with systemd.
    # Useful when updating your config so that you
    # don't need to manually restart it.
    # Default: false
    systemd.enable = true;

    # Configure and theme almost all options from the GUI.
    # Using new flat settings format (not nested objects)
    # See 'https://hyprpanel.com/configuration/settings.html'.
    # Default: <same as gui>
    settings = {
      # General settings
      "tear" = false;
      "scalingPriority" = "hyprland";

      # Bar configuration
      "bar.autoHide" = "fullscreen";
      "bar.launcher.autoDetectIcon" = true;
      "bar.launcher.icon" = "";

      # Workspace configuration
      "bar.workspaces.showAllActive" = false;
      "bar.workspaces.showWsIcons" = false;
      "bar.workspaces.show_icons" = false;
      "bar.workspaces.monitorSpecific" = false;
      "bar.workspaces.workspaces" = 2;
      "bar.workspaces.workspaceMask" = false;
      "bar.workspaces.show_numbered" = true;
      "bar.workspaces.numbered_active_indicator" = "highlight";

      # Media configuration
      "bar.media.format" = "{title} {artist: - }";
      "bar.media.truncation" = false;
      "bar.media.show_label" = true;
      "bar.media.show_active_only" = true;

      # Network configuration
      "bar.network.showWifiInfo" = true;
      "bar.network.truncation_size" = 7;
      "bar.network.truncation" = false;
      "bar.network.label" = false;

      # Other bar modules
      "bar.bluetooth.label" = false;
      "bar.volume.label" = true;
      "bar.clock.showIcon" = true;
      "bar.clock.showTime" = true;
      "bar.clock.format" = "%a %m/%d %H:%M";
      "bar.notifications.show_total" = true;
      "bar.notifications.hideCountWhenZero" = true;
      "bar.customModules.microphone.label" = false;

      # Clock and weather
      "menus.clock.time.military" = true;
      "menus.clock.time.hideSeconds" = true;
      "menus.clock.weather.enabled" = true;
      "menus.clock.weather.location" = "Suffolk";
      "menus.clock.weather.key" = "dde14cc79e324028be572340252405";
      "menus.clock.weather.unit" = "metric";

      # Menu transitions
      "menus.transition" = "crossfade";

      # Media menu
      "menus.media.displayTimeTooltip" = true;

      # Volume menu
      "menus.volume.raiseMaximumVolume" = true;

      # Power menu
      "menus.power.confirmation" = false;
      "menus.power.showLabel" = false;

      # Dashboard configuration
      "menus.dashboard.directories.enabled" = false;
      "menus.dashboard.stats.enable_gpu" = false;
      "menus.dashboard.powermenu.confirmation" = false;
      "menus.dashboard.controls.enabled" = true;

      # Dashboard shortcuts
      "menus.dashboard.shortcuts.left.shortcut1.icon" = "";
      "menus.dashboard.shortcuts.left.shortcut1.command" = "zen-twilight";
      "menus.dashboard.shortcuts.left.shortcut1.tooltip" = "Zen Browser";
      "menus.dashboard.shortcuts.left.shortcut2.command" = "kitty";
      "menus.dashboard.shortcuts.left.shortcut2.icon" = "";
      "menus.dashboard.shortcuts.left.shortcut2.tooltip" = "Kitty Terminal";
      "menus.dashboard.shortcuts.left.shortcut3.command" = "vesktop";
      "menus.dashboard.shortcuts.left.shortcut3.tooltip" = "Vesktop";
      "menus.dashboard.shortcuts.left.shortcut4.command" = "fuzzel";

      # Notifications
      "notifications.showActionsOnHover" = false;
      "notifications.active_monitor" = true;
      "notifications.displayedTotal" = 10;
      "notifications.position" = "top right";

      # Wallpaper
      "wallpaper.enable" = false;

      # Theme configuration
      "theme.name" = "rose_pine";
      "theme.font.name" = "Noto Sans";
      "theme.font.size" = "1.0rem";

      # Bar theme settings
      "theme.bar.floating" = false;
      "theme.bar.opacity" = 40;
      "theme.bar.transparent" = false;
      "theme.bar.outer_spacing" = "0.8em";
      "theme.bar.scaling" = 80;
      "theme.bar.border_radius" = "1.2em";

      # Button theme settings
      "theme.bar.buttons.enableBorders" = false;
      "theme.bar.buttons.y_margins" = "0.4em";
      "theme.bar.buttons.spacing" = "0.4em";
      "theme.bar.buttons.opacity" = 100;
      "theme.bar.buttons.workspaces.smartHighlight" = true;
      "theme.bar.buttons.modules.netstat.enableBorder" = true;

      # Menu theme settings
      "theme.bar.menus.popover.scaling" = 64;
      "theme.bar.menus.monochrome" = false;
      "theme.bar.menus.menu.dashboard.scaling" = 80;
      "theme.bar.menus.menu.media.scaling" = 80;
      "theme.bar.menus.menu.clock.scaling" = 80;
      "theme.bar.menus.menu.power.scaling" = 100;
      "theme.bar.menus.menu.notifications.pager.show" = true;

      # Notification theme
      "theme.notification.scaling" = 80;
      "theme.notification.border_radius" = "1.2em";

      # OSD theme
      "theme.osd.enable" = true;
      "theme.osd.location" = "top";
      "theme.osd.orientation" = "horizontal";
      "theme.osd.muted_zero" = false;
      "theme.osd.margins" = "32px";
      "theme.osd.active_monitor" = true;
      "theme.osd.monitor" = 1;
    };
  };
}