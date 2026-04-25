# nix-options.nix
#
# Purpose: Centralized Nix configuration options
#
# This module:
# - Defines Nix experimental features
# - Sets up garbage collection
# - Configures trusted users
{ lib, userConfig, ... }:
let
  userData = userConfig.user or userConfig;
  username = userData.username or userConfig.username;
in
{
  nix.settings = {
    max-jobs = 1;
    cores = 0;
    experimental-features = [
      "nix-command"
      "flakes"
      "fetch-tree"
      "impure-derivations"
      "ca-derivations"
      "pipe-operators"
    ];
    auto-optimise-store = true;
    min-free = 0;

    trusted-users = lib.mkAfter [
      "root"
      "${username}"
    ];
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  nixpkgs.config.allowUnfree = true;
}
