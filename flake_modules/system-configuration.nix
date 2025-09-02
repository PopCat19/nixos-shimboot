{ self, nixpkgs, home-manager, ... }:

let
  system = "x86_64-linux";

  # Base = required system configuration only
  baseModules = [
    ../shimboot_config/base_configuration/configuration.nix

    # Base-level defaults/tuning common to all variants
    ({ config, pkgs, ... }: {
      # Enable Nix flakes
      nix.settings.experimental-features = [ "nix-command" "flakes" ];

      # Enable automatic garbage collection
      nix.gc = {
        automatic = true;
        dates = "weekly";
        options = "--delete-older-than 30d";
      };
    })
  ];

  # Main = user configuration that itself imports base; keeps flake from duplicating base
  mainModules = [
    ../shimboot_config/main_configuration/configuration.nix

    # Integrate Home Manager for user-level config
    home-manager.nixosModules.home-manager

    ({ config, pkgs, ... }: {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;

      # Delegate actual HM content to home.nix (split into programs.nix and packages.nix)
      home-manager.users."nixos-user" = import ../shimboot_config/main_configuration/home_modules/home.nix;
    })
  ];
in {
  # NixOS configurations for building the system
  nixosConfigurations = {
    # Strict base system (required components only)
    raw-efi-system = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = baseModules;
      specialArgs = { inherit self; };
    };

    # Full main system (base + optional/user modules inc. HM)
    nixos-shimboot = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = mainModules;
      specialArgs = { inherit self; };
    };
  };
}