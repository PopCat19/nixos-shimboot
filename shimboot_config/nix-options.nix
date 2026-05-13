# nix-options.nix
#
# Purpose: Centralized Nix configuration options
#
# This module:
# - Defines Nix experimental features
# - Configures binary caches and trusted keys
# - Disables sandbox (ChromeOS kernel limitation)
# - Disables nix.gc (delegated to programs.nh.clean)
{ lib, userConfig, ... }:
let
  userData = userConfig.user or userConfig;
  username = userData.username or userConfig.username;
in
{
  nix.settings = {
    max-jobs = 1;
    cores = 0;
    sandbox = false;
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
      "https://hyprland.cachix.org"
    ];

    trusted-public-keys = lib.mkAfter [
      "shimboot-systemd-nixos.cachix.org-1:vCWmEtJq7hA2UOLN0s3njnGs9/EuX06kD7qOJMo2kAA="
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
    ];
  };

  # GC delegated to programs.nh.clean (see system/nh.nix).
  # nix.gc and programs.nh.clean must not both be enabled.
  nix.gc.automatic = false;

  nixpkgs.config.allowUnfree = true;
}
