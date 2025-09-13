{
  pkgs,
  config,
  ...
}: {
  # Micro text editor configuration
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

  # Micro editor colorscheme
  home.file.".config/micro/colorschemes/rose-pine.micro" = {
    source = ../micro_config/rose-pine.micro;
  };
}
