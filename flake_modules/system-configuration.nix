{ self, nixpkgs, home-manager, zen-browser, ... }:

let
  system = "x86_64-linux";

  # Import user configuration
  userConfig = import ../shimboot_config/user-config.nix { };

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
      home-manager.extraSpecialArgs = { inherit zen-browser userConfig; inputs = self.inputs; };

      # Make userConfig available to home modules
      home-manager.sharedModules = [
        ({ config, ... }: {
          _module.args.userConfig = userConfig;
        })
      ];

      # Delegate actual HM content to home.nix (split into programs.nix and packages.nix)
      home-manager.users."${userConfig.user.username}" = import ../shimboot_config/main_configuration/home_modules/home.nix;
    })
  ];
in {
  # NixOS configurations for building the system
  nixosConfigurations = {
    # Strict base system (required components only)
    raw-efi-system = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = baseModules;
      specialArgs = { inherit self zen-browser; };
    };

    # Full main system (base + optional/user modules inc. HM)
    nixos-shimboot = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = mainModules;
      specialArgs = { inherit self zen-browser; };
    };
  };
}