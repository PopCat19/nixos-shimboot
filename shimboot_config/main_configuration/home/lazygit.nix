# LazyGit Module
#
# Purpose: Configure LazyGit
# Dependencies: None
#
# This module:
# - Enables LazyGit via home-manager
_: {
  programs.lazygit = {
    enable = true;
  };
}
