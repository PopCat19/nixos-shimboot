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
          # Print the greeter
          echo "Welcome to NixOS Shimboot!"
          echo "For documentation and to report bugs, please visit the project's Github page:"
          echo " - https://github.com/popcat19/nixos-shimboot"

          # Check if rootfs needs expansion
          set -l percent_full (df -BM / | tail -n1 | awk '{print $5}' | tr -d '%')
          set -l total_size (df -BM / | tail -n1 | awk '{print $2}' | tr -d 'M')

          if test "$percent_full" -gt 80 -a "$total_size" -lt 7000
            echo
            echo "Warning: Your storage is nearly full and you have not yet expanded the root filesystem. Run 'sudo expand_rootfs' to fix this."
          end

          echo
          if type -q setup_nixos
            echo "Tip: run 'setup_nixos' to configure Wi-Fi, expand rootfs, and set up your flake."
          end
        end
      '';
    };
  };
}