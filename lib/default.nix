# Helper Functions Library
#
# Purpose: Reusable helper functions for NixOS configuration
# Dependencies: nixpkgs lib
# Related: vars/default.nix, flake.nix
#
# This file:
# - Provides mkHost function for creating host configurations
# - Provides helper functions for common patterns
{
  # Create a host configuration with Home Manager integration
  mkHost = hostname: extraModules: { inputs, nixpkgs, vars, hostName ? hostname }:
    nixpkgs.lib.nixosSystem {
      system = vars.system;
      specialArgs = { inherit inputs vars hostName; };
      modules = [
        ./hosts/${hostname}/configuration.nix
        inputs.home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.extraSpecialArgs = { inherit inputs vars hostName; };
          home-manager.users.${vars.username} = {
            imports = [ ./hosts/${hostname}/home.nix ];
          };
        }
      ] ++ extraModules;
    };
}
