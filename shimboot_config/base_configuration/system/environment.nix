# Global Environment Variables Module
#
# Purpose: Set system-wide environment variables for all users
#
# This module:
# - Sets global environment variables accessible to all processes
# - Configures NixOS-specific paths and host information
#
# Priority strategy (lib.mkOverride):
# - 10  = mkVMOverride (VM builds)
# - 50  = mkForce (emergency override)
# - 60  = mkImageMediaOverride (image profiles)
# - 100 = normal assignment (consumer override)
# - 500 = BASE CONFIG (beats NixOS, loses to consumer)
# - 1000 = mkDefault (NixOS defaults)
# - 1500 = mkOptionDefault (option definitions)
#
# Base uses 500: wins over NixOS mkDefault (1000), consumers override with normal (100)
{ lib, userConfig, ... }:
{
  environment.variables = {
    EDITOR = lib.mkOverride 500 userConfig.defaultApps.editor.command;
    VISUAL = lib.mkOverride 500 userConfig.defaultApps.editor.command;
    NIXOS_CONFIG_DIR = lib.mkOverride 500 userConfig.env.NIXOS_CONFIG_DIR;
    NIXOS_CONFIG_PATH = lib.mkOverride 500 "${userConfig.env.NIXOS_CONFIG_DIR}/shimboot_config";
    NIXOS_FLAKE_HOSTNAME = lib.mkOverride 500 userConfig.host.hostname;
    PATH = lib.mkOverride 500 "$HOME/bin:$HOME/.npm-global/bin:$PATH";
  };
}
