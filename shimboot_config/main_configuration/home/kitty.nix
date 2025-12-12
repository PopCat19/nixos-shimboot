# Kitty Terminal Module
#
# Purpose: Configure Kitty terminal emulator
# Dependencies: theme_config/applications/kitty.nix
# Related: theme.nix
#
# This module:
# - Imports Kitty theme configuration from theme_config
# - Enables Kitty with Fish shell integration
# - Provides terminal configuration
{lib, pkgs, config, inputs, ...}: {
  imports = [
    ./theme_config/applications/kitty.nix
  ];

  programs.kitty = {
    enable = true;
    settings = {
      shell = "fish";
      shell_integration = "enabled";
      confirm_os_window_close = -1;
      cursor_shape = "block";
      cursor_blink_interval = 0.5;
      cursor_stop_blinking_after = 16.0;
      cursor_trail = 1;
      scrollback_lines = 10000;
      mouse_hide_wait = 3.0;
      detect_urls = "yes";
      repaint_delay = 10;
      input_delay = 3;
      sync_to_monitor = "yes";
      enable_audio_bell = "yes";
      visual_bell_duration = 0.0;
      remember_window_size = "yes";
    };
  };
}
