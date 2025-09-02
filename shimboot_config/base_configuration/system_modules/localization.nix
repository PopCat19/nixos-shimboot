{ config, pkgs, lib, ... }:

{
  # Console and Localization
  time.timeZone = "America/New_York"; # Timezone
  i18n.defaultLocale = "en_US.UTF-8"; # Default locale
}