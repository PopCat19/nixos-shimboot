# Core Home Modules
#
# Purpose: Bundle core Home Manager configuration modules
# Dependencies: All core modules in this directory
# Related: modules/home/cli, modules/home/desktop, modules/home/apps
#
# This bundle:
# - Configures home environment
# - Sets up user services
# - Applies theme via stylix
# - Configures noctalia shell
{
  imports = [
    ./environment.nix
    ./services.nix
    ./stylix.nix
    ./noctalia_config/noctalia.nix
    ./programs.nix
  ];
}
