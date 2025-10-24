# Micro Text Editor Module
#
# Purpose: Configure Micro text editor with Rose Pine theme
# Dependencies: micro_config/rose-pine.micro
# Related: None
#
# This module:
# - Enables Micro with custom settings
# - Installs Rose Pine color scheme
# - Configures editor behavior and appearance

{
  pkgs,
  config,
  ...
}: {
  programs.micro = {
    enable = true;
    settings = {
      colorscheme = "rose-pine";
      mkparents = true;
      softwrap = true;
      wordwrap = true;
      tabsize = 4;
      autoclose = true;
      autoindent = true;
      autosave = 5;
      clipboard = "terminal";
      cursorline = true;
      diffgutter = true;
      ignorecase = true;
      scrollbar = true;
      smartpaste = true;
      statusline = true;
      syntax = true;
      tabstospaces = true;
    };
  };

  home.file.".config/micro/colorschemes/rose-pine.micro" = {
    source = ../micro_config/rose-pine.micro;
  };
}
