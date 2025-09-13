{
  config,
  pkgs,
  lib,
  ...
}: {
  # Main system configuration imports base configuration and adds optional/user modules
  imports = [
    ../base_configuration/configuration.nix
    ./system_modules/display.nix
    ./system_modules/fonts.nix
    ./system_modules/packages.nix
    ./system_modules/services.nix
    # Add more user/optional system modules here as needed
  ];
}
