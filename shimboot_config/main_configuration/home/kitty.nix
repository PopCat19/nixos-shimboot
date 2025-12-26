{pkgs, ...}: {
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
      url_color = "#c4a7e7";
      url_style = "curly";
      detect_urls = "yes";
      repaint_delay = 10;
      input_delay = 3;
      sync_to_monitor = "yes";
      enable_audio_bell = "yes";
      visual_bell_duration = 0.0;
      remember_window_size = "yes";
      window_border_width = 0.5;
      window_margin_width = 8;
      window_padding_width = 12;
      active_border_color = "#ebbcba";
      inactive_border_color = "#26233a";
      tab_bar_edge = "bottom";
      tab_bar_style = "separator";
      tab_separator = " | ";
      active_tab_foreground = "#e0def4";
      active_tab_background = "#26233a";
      inactive_tab_foreground = "#908caa";
      inactive_tab_background = "#191724";
      foreground = "#e0def4";
      background = "#191724";
      selection_foreground = "#e0def4";
      selection_background = "#403d52";
      dynamic_background_opacity = "yes";
      background_blur = 16;
    };
  };
}
