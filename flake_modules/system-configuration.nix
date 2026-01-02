{
  self,
  nixpkgs,
  home-manager,
  zen-browser,
  rose-pine-hyprcursor,
  noctalia,
  stylix,
  ...
}: let
  system = "x86_64-linux";
  lib = nixpkgs.lib;

  # Import user configuration
  userConfig = import ../shimboot_config/user-config.nix {};
  # Hostname (used to expose .#HOSTNAME and .#HOSTNAME-minimal)
  hn = userConfig.host.hostname;

  # Base = required system configuration only
  baseModules = [
    ../shimboot_config/base_configuration/configuration.nix

    # Base-level defaults/tuning common to all variants
    ({
      config,
      pkgs,
      ...
    }: {
      # Enable Nix flakes
      nix.settings.experimental-features = ["nix-command" "flakes"];

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

    ({
      config,
      pkgs,
      ...
    }: {
      home-manager.useGlobalPkgs = false;
      home-manager.useUserPackages = true;
      home-manager.extraSpecialArgs = {
        inherit zen-browser rose-pine-hyprcursor userConfig;
        inputs = self.inputs;
      };

      # Make userConfig available to home modules
      home-manager.sharedModules = [
        ({...}: {
          nixpkgs.config.allowUnfree = true;
          nixpkgs.overlays = import ../overlays/overlays.nix pkgs.system;
          _module.args.userConfig = userConfig;
        })
      ];

      # Delegate actual HM content to home.nix (split into programs.nix and packages.nix)
      home-manager.users."${userConfig.user.username}" = import ../shimboot_config/main_configuration/home/home.nix;
    })
  ];
in {
  # NixOS configurations for building the system
  nixosConfigurations = let
    baseSet = {
      # Minimal/base-only target (host-qualified)
      "${hn}-minimal" = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = baseModules;
        specialArgs = {inherit self zen-browser rose-pine-hyprcursor noctalia stylix userConfig;};
      };

      # Full target (host-qualified, preferred)
      "${hn}" = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = mainModules;
        specialArgs = {inherit self zen-browser rose-pine-hyprcursor noctalia stylix userConfig;};
      };
    };

    compatRaw = lib.optionalAttrs (hn != "raw-efi-system") {
      raw-efi-system = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = baseModules;
        specialArgs = {inherit self zen-browser rose-pine-hyprcursor noctalia stylix userConfig;};
      };
    };

    compatShimboot = lib.optionalAttrs (hn != "nixos-shimboot") {
      nixos-shimboot = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = mainModules;
        specialArgs = {inherit self zen-browser rose-pine-hyprcursor stylix;};
      };
    };
  in
    baseSet // compatRaw // compatShimboot;
}
