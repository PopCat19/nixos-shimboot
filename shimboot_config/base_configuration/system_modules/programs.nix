{ ... }:

{
  # System programs configuration
  # Fish and Starship are configured in home_modules for user-specific settings.
  
  programs = {
    # Shell configuration
    fish = {
      enable = true;
      interactiveShellInit = ''
        function fish_greeting --description 'Shimboot greeting'
          if type -q shimboot_greeter
            shimboot_greeter
          else
            echo Welcome to NixOS Shimboot
          end
          if type -q setup_nixos
            echo "Tip: run 'setup_nixos' to configure Wi-Fi, expand rootfs, and set up your flake."
          end
        end
      '';
    };
  };
}