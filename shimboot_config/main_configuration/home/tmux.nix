# tmux.nix
#
# Purpose: Configure tmux terminal multiplexer
#
# This module:
# - Enables tmux
# - Enables mouse support for pane/window selection
_: {
  programs.tmux = {
    enable = true;
    mouse = true;
  };
}
