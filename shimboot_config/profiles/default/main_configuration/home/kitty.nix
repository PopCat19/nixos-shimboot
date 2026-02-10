_: {
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
      tab_bar_edge = "bottom";
      tab_bar_style = "separator";
      tab_separator = " | ";
      dynamic_background_opacity = "yes";
      background_blur = 16;
    };
  };
}
