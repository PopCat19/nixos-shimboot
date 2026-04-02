# Broot Module
#
# Purpose: Configure Broot file manager
# Dependencies: None
#
# This module:
# - Enables Broot via home-manager
_: {
  programs.broot = {
    enable = true;
  };
}
