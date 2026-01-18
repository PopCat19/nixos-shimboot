# Core System Modules
#
# Purpose: Bundle all core system configuration modules
# Dependencies: All core modules in this directory
# Related: modules/nixos/desktop, modules/nixos/hardware
#
# This bundle:
# - Imports base system configuration
# - Configures Nix settings and binary caches
# - Enables Fish shell and unfree packages
# - Sets system state version
{ lib, ... }:
let
  vars = import ../../../vars;
in
{
  imports = [
    ./environment.nix
    ./boot.nix
    ./networking.nix
    ./filesystems.nix
    ./packages.nix
    ./security.nix
    ./systemd-patch.nix
    ./kill-frecon.nix
    ./localization.nix
    ./users.nix
    ./fish.nix
    ./services.nix
    ./helpers/helpers.nix
  ];

  _module.args.vars = vars;

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    trusted-users = lib.mkAfter [
      "root"
      "${vars.username}"
    ];
    substituters = lib.mkAfter [ "https://shimboot-systemd-nixos.cachix.org" ];
    trusted-public-keys = lib.mkAfter [
      "shimboot-systemd-nixos.cachix.org-1:vCWmEtJq7hA2UOLN0s3njnGs9/EuX06kD7qOJMo2kAA="
    ];
    auto-optimise-store = true;
    min-free = 0;
  };

  nixpkgs.config.allowUnfree = true;

  system.stateVersion = "24.11";
}
