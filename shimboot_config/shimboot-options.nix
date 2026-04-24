# shimboot-options.nix
#
# Purpose: Define shimboot-specific NixOS options
#
# This module:
# - Declares the shimboot.headless option for headless/desktop mode switching
# - Declares the shimboot.board option for hardware-specific configuration
{
  lib,
  config,
  ...
}:
{
  options.shimboot = {
    headless = lib.mkEnableOption "headless mode (SSH-only, no desktop)";

    board = lib.mkOption {
      type = lib.types.enum [
        # Intel boards
        "dedede"
        "octopus"
        "nissa"
        "hatch"
        "brya"
        "snappy"
        # AMD boards
        "zork"
        "grunt"
        # ARM boards
        "jacuzzi"
        "corsola"
        "hana"
        "trogdor"
      ];
      default = null;
      description = ''
        ChromeOS board identifier for hardware-specific configuration.

        Required for correct driver and kernel module loading.

        Intel boards:  dedede, octopus, nissa, hatch, brya, snappy
        AMD boards:    zork, grunt
        ARM boards:    jacuzzi, corsola, hana, trogdor

        To find your board:
        - Check your build: ./assemble-final.sh --board <board>
        - Or run: cat /sys/class/dmi/id/product_name
      '';
    };
  };

  # Fail early if board is not set - required for proper hardware config
  config = lib.mkIf (config.shimboot.board == null) {
    assertions = [
      {
        assertion = false;
        message = ''
          shimboot.board must be set!

          Add to your configuration:
            shimboot.board = "dedede";  # or your board name

          Available boards:
            Intel: dedede, octopus, nissa, hatch, brya, snappy
            AMD:   zork, grunt
            ARM:   jacuzzi, corsola, hana, trogdor

          To find your board:
          - Check your build command: ./assemble-final.sh --board <board>
          - Or check hardware: cat /sys/class/dmi/id/product_name
          - Common models: Drawcia→dedede, Dooly→dedede, Woomy→dedede
        '';
      }
    ];
  };
}
