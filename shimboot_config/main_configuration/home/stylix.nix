# Stylix Theme Module
#
# Purpose: Configure comprehensive theming using Stylix framework with Rose Pine color scheme
# Dependencies: stylix, base16-schemes, nerd-fonts, google-fonts, papirus-icon-theme
# Related: fonts.nix, display.nix, greeter.nix
#
# This module:
# - Sets up Rose Pine Base16 color scheme via Stylix
# - Configures fonts: Rounded Mplus 1c + FiraCode Nerd Font + Noto Color Emoji
# - Manages GTK, Qt, and desktop environment theming comprehensively
# - Provides cursor and icon theme integration
# - Handles browser theming targets (Firefox-based browsers)
# - Applies system-wide theming across all applications
{
  pkgs,
  inputs,
  ...
}: {
  imports = [
    inputs.stylix.homeModules.stylix
  ];

  # Enable Stylix with auto-enable for better compatibility
  stylix.enable = true;
  stylix.autoEnable = true;

  # Use Rose Pine Base16 color scheme
  stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/rose-pine.yaml";

  # Enhanced font configuration with all font types
  stylix.fonts = {
    serif = {
      package = pkgs.noto-fonts;
      name = "Noto Serif";
    };

    sansSerif = {
      package = pkgs.google-fonts;
      name = "Rounded Mplus 1c Medium";
    };

    monospace = {
      package = pkgs.nerd-fonts.fira-code;
      name = "FiraCode Nerd Font";
    };

    emoji = {
      package = pkgs.noto-fonts-color-emoji;
      name = "Noto Color Emoji";
    };
  };

  # Font sizes for specific contexts
  stylix.fonts.sizes = {
    applications = 10; # For applications like fuzzel
    terminal = 10; # For terminal applications like kitty
    popups = 10; # For popup dialogs
    desktop = 10; # For desktop applications
  };

  # Enable theming targets for comprehensive coverage
  stylix.targets.zen-browser.enable = true;
  stylix.targets.zen-browser.profileNames = ["default"];
  stylix.targets.vesktop.enable = true;
  stylix.targets.vencord.enable = true;
  stylix.targets.nixcord.enable = true;

  # Cursor theme configuration using Stylix native option
  stylix.cursor = {
    name = "rose-pine-hyprcursor";
    package = pkgs.rose-pine-hyprcursor;
    size = 24;
  };

  # Icon theme configuration using Stylix native option
  stylix.icons = {
    enable = true;
    package = pkgs.papirus-icon-theme;
    dark = "Papirus-Dark";
  };

  # Additional packages for comprehensive theming coverage
  home.packages = with pkgs; [
    papirus-icon-theme
    # Fallback icon themes for missing icons
    adwaita-icon-theme
    # Qt styling tools for platform theme support
    kdePackages.qt6ct
  ];

  # KDE global configuration for icon theme
  home.file.".config/kdeglobals".text = ''
    [Icons]
    Theme=Papirus-Dark
  '';
}
