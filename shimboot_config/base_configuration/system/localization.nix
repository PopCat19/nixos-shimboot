# Localization Configuration Module
#
# Purpose: Configure system locale and timezone settings
# Dependencies: glibc, user-config.nix
# Related: services.nix, user-config.nix
#
# This module:
# - Uses timezone and locale from user-config.nix
# - Allows user customization of localization settings
{
  lib,
  userConfig,
  ...
}:
{
  time.timeZone = lib.mkDefault userConfig.timezone;
  i18n.defaultLocale = lib.mkDefault userConfig.locale;
}
