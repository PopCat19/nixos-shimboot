# System Configuration Module
#
# Purpose: Generate NixOS configurations using modular structure
# Dependencies: vars/, modules/, hosts/
# Related: flake.nix
#
# This module:
# - Imports vars for configuration
# - Creates base and main configurations
# - Integrates Home Manager
# - Maintains backward compatibility with existing outputs
{
  self,
  nixpkgs,
  home-manager,
  zen-browser,
  rose-pine-hyprcursor,
  noctalia,
  stylix,
  ...
}:
let
  system = "x86_64-linux";
  inherit (nixpkgs) lib;

  # Import variables from vars/default.nix
  vars = import ../vars;
  # Hostname (used to expose .#HOSTNAME and .#HOSTNAME-minimal)
  hn = vars.host.hostname;

  # Base = required system configuration only
  baseModules = [
    ../modules/nixos/core
    ../modules/nixos/hardware

    # Base-level defaults/tuning common to all variants
    (_: {
      # Enable Nix flakes
      nix.settings.experimental-features = [
        "nix-command"
        "flakes"
      ];

      # Enable automatic garbage collection
      nix.gc = {
        automatic = true;
        dates = "weekly";
        options = "--delete-older-than 30d";
      };
    })
  ];

  # Main = user configuration with desktop environment
  mainModules = [
    ../modules/nixos/core
    ../modules/nixos/desktop
    ../modules/nixos/hardware
    ../modules/nixos/profiles/shimboot

    # Integrate Home Manager for user-level config
    home-manager.nixosModules.home-manager

    (
      { pkgs, ... }:
      {
        home-manager.useGlobalPkgs = false;
        home-manager.useUserPackages = true;
        home-manager.extraSpecialArgs = {
          inherit zen-browser rose-pine-hyprcursor vars;
          inherit (self) inputs;
        };

        # Make vars available to home modules
        home-manager.sharedModules = [
          (_: {
            nixpkgs.config.allowUnfree = true;
            nixpkgs.overlays = import ../overlays/overlays.nix pkgs.system;
            _module.args.vars = vars;
          })
        ];

        # Delegate actual HM content to home.nix
        home-manager.users."${vars.username}" =
          import ../hosts/shimboot/home.nix;
      }
    )
  ];
in
{
  # NixOS configurations for building the system
  nixosConfigurations =
    let
      baseSet = {
        # Minimal/base-only target (host-qualified)
        "${hn}-minimal" = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = baseModules;
          specialArgs = {
            inherit
              self
              zen-browser
              rose-pine-hyprcursor
              noctalia
              stylix
              vars
              ;
          };
        };

        # Full target (host-qualified, preferred)
        "${hn}" = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = mainModules;
          specialArgs = {
            inherit
              self
              zen-browser
              rose-pine-hyprcursor
              noctalia
              stylix
              vars
              ;
          };
        };
      };

      compatRaw = lib.optionalAttrs (hn != "raw-efi-system") {
        raw-efi-system = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = baseModules;
          specialArgs = {
            inherit
              self
              zen-browser
              rose-pine-hyprcursor
              noctalia
              stylix
              vars
              ;
          };
        };
      };

      compatShimboot = lib.optionalAttrs (hn != "nixos-shimboot") {
        nixos-shimboot = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = mainModules;
          specialArgs = {
            inherit
              self
              zen-browser
              rose-pine-hyprcursor
              stylix
              vars
              ;
          };
        };
      };
    in
    baseSet // compatRaw // compatShimboot;
}
