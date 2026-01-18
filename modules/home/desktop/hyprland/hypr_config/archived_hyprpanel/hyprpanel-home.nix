# HyprPanel Home Configuration Module
#
# Purpose: Configure HyprPanel with host-specific bar layouts
# Dependencies: vars
# Related: hyprpanel-common.nix, hyprland.nix
#
# This module:
# - Defines bar layouts for different monitors
# - Configures dashboard shortcuts using vars
# - Provides home-specific HyprPanel settings
{
  vars,
  pkgs,
  lib,
  ...
}:
{
  programs.hyprpanel = {
    enable = true;
    systemd.enable = true;

    settings = {
      # Layout configuration - Configure bar layouts for monitors
      "bar.layouts" = {
        "*" = {
          left = [
            "dashboard"
            "workspaces"
            "media"
          ];
          middle = [ ];
          right = [
            "cputemp"
            "battery"
            "network"
            "bluetooth"
            "volume"
            "systray"
            "clock"
            "notifications"
          ];
        };
      };

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
      "menus.clock.weather.enabled" = false;

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
      "menus.dashboard.shortcuts.left.shortcut1.command" = vars.defaultApps.browser.command;
      "menus.dashboard.shortcuts.left.shortcut1.tooltip" = "Zen Browser";
      "menus.dashboard.shortcuts.left.shortcut2.command" = vars.defaultApps.terminal.command;
      "menus.dashboard.shortcuts.left.shortcut2.icon" = "";
      "menus.dashboard.shortcuts.left.shortcut2.tooltip" = "Kitty Terminal";
      "menus.dashboard.shortcuts.left.shortcut3.command" = "vesktop";
      "menus.dashboard.shortcuts.left.shortcut3.tooltip" = "Vesktop";
      "menus.dashboard.shortcuts.left.shortcut4.command" = vars.defaultApps.launcher.command;

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

  # Fix service dependencies
  systemd.user.services.hyprpanel = {
    Unit = {
      Description = "Bar/Panel for Hyprland with extensive customizability";
      After = [
        "graphical-session.target"
        "hyprland-session.target"
      ];
      PartOf = [ "graphical-session.target" ];
      # Remove ConditionEnvironment check; rely on After= instead
      ConditionEnvironment = lib.mkForce [ ];
    };

    Service = {
      ExecStart = lib.mkForce "${pkgs.hyprpanel}/bin/hyprpanel";
      Restart = "on-failure";
      RestartSec = "3s";
      # Ensure WAYLAND_DISPLAY is inherited from Hyprland session
      Environment = "PATH=/run/current-system/sw/bin";
    };

    Install.WantedBy = [ "hyprland-session.target" ];
  };
}
