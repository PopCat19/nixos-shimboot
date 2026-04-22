# shimboot-options.nix
#
# Purpose: Define shimboot-specific NixOS options
#
# This module:
# - Declares the shimboot.headless option for headless/desktop mode switching
{
  lib,
  ...
}:
{
  options.shimboot = {
    headless = lib.mkEnableOption "headless mode (SSH-only, no desktop)";
  };
}
