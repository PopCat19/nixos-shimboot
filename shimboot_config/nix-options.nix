# nix-options.nix
#
# Purpose: Centralized Nix configuration options
#
# This module:
# - Defines Nix experimental features
# - Configures binary caches and trusted keys
# - Sets up garbage collection
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

    substituters = lib.mkAfter [
      "https://shimboot-systemd-nixos.cachix.org"
      "https://cache.numtide.com"
    ];

    trusted-public-keys = lib.mkAfter [
      "shimboot-systemd-nixos.cachix.org-1:vCWmEtJq7hA2UOLN0s3njnGs9/EuX06kD7qOJMo2kAA="
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
    ];
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  nixpkgs.config.allowUnfree = true;
}
