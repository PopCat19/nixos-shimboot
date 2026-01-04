# Helpers Module
#
# Purpose: Provide shell wrappers for helper scripts
# Dependencies: fish, ./*.fish files
# Related: system modules, fish.nix
#
# This module:
# - Provides unified access to helper scripts via shell wrappers
# - Fish functions are loaded by fish.nix via environment.etc
# - Maintains portability by keeping logic in fish files
{pkgs, ...}: let
  # Create shell wrapper for a fish function
  createFishWrapper = name: ''
    if command -v fish >/dev/null 2>&1; then
      fish -c "${name} $*"
    else
      echo "Error: fish shell is required for this helper"
      exit 1
    fi
  '';
in {
  environment.systemPackages = with pkgs; [
    # Shell wrappers for all fish functions in this directory
    (writeShellScriptBin "fix-steam-bwrap" (createFishWrapper "fix-steam-bwrap"))
    (writeShellScriptBin "expand_rootfs" (createFishWrapper "expand_rootfs"))
    (writeShellScriptBin "setup_nixos_config" (createFishWrapper "setup_nixos_config"))
    (writeShellScriptBin "setup_nixos" (createFishWrapper "setup_nixos"))
  ];
}
