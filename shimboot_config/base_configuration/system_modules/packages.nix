{ config, pkgs, lib, ... }:

{
  # Package Configuration
  environment.systemPackages = with pkgs; [ # System-wide packages
    micro
    git
    btop
    kitty # Terminal emulator
    fastfetch
    hwinfo
    fish
  ];

  programs.fish = {
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
}