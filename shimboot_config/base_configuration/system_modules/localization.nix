{ config, pkgs, lib, ... }:

{
  # Console and Localization
  time.timeZone = "America/New_York"; # Timezone
  i18n.defaultLocale = "en_US.UTF-8"; # Default locale
  
  users.motd = '' # Message of the day
    Welcome to NixOS Shimboot!
    For documentation and to report bugs, please visit the project's Github page.

    Run 'expand_rootfs' if you need to expand the root filesystem.
    Run 'shimboot_greeter' for system information.
  '';
}