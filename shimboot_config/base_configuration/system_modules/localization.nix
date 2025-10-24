# Localization Configuration Module
#
# Purpose: Configure system locale and timezone settings
# Dependencies: glibc
# Related: services.nix
#
# This module:
# - Sets default timezone to America/New_York
# - Configures default locale to en_US.UTF-8

{
  config,
  pkgs,
  lib,
  ...
}: {
  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";
}
