# nix-options.nix
#
# Purpose: Centralized Nix configuration options
#
# This module:
# - Defines Nix experimental features
# - Configures binary caches and trusted keys
# - Sets up garbage collection
#
# Warning: Nix reads config from multiple sources. If the daemon
# reports fewer experimental-features than defined here, check for
# a root-level override at /root/.config/nix/nix.conf. The daemon
# runs as root and that file takes precedence over /etc/nix/nix.conf.
{ lib, userConfig, ... }:
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
      "${userConfig.user.username}"
    ];

    substituters = lib.mkAfter [
      "https://cache.nixos.org"
      "https://shimboot-systemd-nixos.cachix.org"
      "https://cache.numtide.com"
    ];

    trusted-public-keys = lib.mkAfter [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
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
