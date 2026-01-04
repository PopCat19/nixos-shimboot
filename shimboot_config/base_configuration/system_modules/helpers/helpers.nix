# Helpers Module
#
# Purpose: Provide shell wrappers for fish helper functions
# Dependencies: fish, ./*.fish files
# Related: system modules, fish_functions
#
# This module:
# - Provides unified access to helper scripts via shell wrappers
# - Creates shell wrappers that call portable fish functions from ./*.fish files
# - Maintains portability by keeping logic in fish files
{
  pkgs,
  userConfig,
  ...
}: let
  # List of fish function files in this directory
  # Create shell wrapper for a fish function
  createFishWrapper = name: ''
    if command -v fish >/dev/null 2>&1; then
      fish -c "${name} $*"
    else
      echo "Error: fish shell is required for this helper"
      exit 1
    fi
  '';
  # Extract function name from fish filename (remove .fish extension)
in {
  environment.systemPackages = with pkgs; [
    # Shell wrappers for all fish functions in this directory
    (writeShellScriptBin "fix-steam-bwrap" (createFishWrapper "fix-steam-bwrap"))
    (writeShellScriptBin "expand_rootfs" (createFishWrapper "expand_rootfs"))
    (writeShellScriptBin "setup_nixos_config" (createFishWrapper "setup_nixos_config"))
    (writeShellScriptBin "setup_nixos" (createFishWrapper "setup_nixos"))
  ];
}
