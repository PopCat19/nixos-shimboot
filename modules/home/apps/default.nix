# Applications Modules
#
# Purpose: Bundle desktop applications
# Dependencies: All app modules in this directory
# Related: modules/home/core, modules/home/desktop
#
# This bundle:
# - Configures Zen browser
# - Sets up Vesktop (Discord)
# - Configures VSCodium
# - Sets up privacy tools
{
  imports = [
    ./zen-browser.nix
    ./vesktop.nix
    ./vscodium.nix
    ./privacy.nix
  ];
}
