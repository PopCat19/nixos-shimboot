{
  lib,
  pkgs,
  config,
  inputs,
}: let
  system = "x86_64-linux";
  # Core Rose Pine Palette (hex without 0x prefix for easy use)
  rosePineColors = {
    base = "191724";
    surface = "1f1d2e";
    overlay = "26233a";
    muted = "6e6a86";
    subtle = "908caa";
    text = "e0def4";
    love = "eb6f92";
    gold = "f6c177";
    rose = "ebbcba";
    pine = "31748f";
    foam = "9ccfd8";
    iris = "c4a7e7";
    highlightLow = "21202e";
    highlightMed = "403d52";
    highlightHigh = "524f67";
  };

  # Theme Variants: main (default)
  variants = {
    main = {
      gtkThemeName = "Rose-Pine-Main-BL";
      iconTheme = "Rose-Pine";
      cursorTheme = "rose-pine-hyprcursor";
      kvantumTheme = "rose-pine-rose";
      # Use base colors for main
      colors = rosePineColors;
    };
  };

  # Default variant
  defaultVariant = variants.main;

  # Fonts
  fonts = {
    main = "Rounded Mplus 1c Medium";
    mono = "JetBrainsMono Nerd Font";
    sizes = {
      fuzzel = 14;
      kitty = 11;
      gtk = 11;
    };
  };

  # Packages (common)
  commonPackages = with pkgs; [
    inputs.rose-pine-hyprcursor.packages.${system}.default
    rose-pine-gtk-theme-full
    kdePackages.qtstyleplugin-kvantum
    papirus-icon-theme
    nwg-look
    libsForQt5.qt5ct
    qt6ct
    polkit_gnome
    gsettings-desktop-schemas
    # Fonts
    google-fonts
    nerd-fonts.jetbrains-mono
    nerd-fonts.caskaydia-cove
    nerd-fonts.fantasque-sans-mono
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-emoji
    font-awesome
  ];

  # Generate GTK CSS from fonts
  mkGtkCss = fontMain: ''
    * {
      font-family: "${fontMain}";
    }
  '';

  # Session Variables from variant
  mkSessionVariables = variant: sizes: {
    QT_STYLE_OVERRIDE = "kvantum";
    QT_QPA_PLATFORM = "wayland;xcb";
    GTK_THEME = variant.gtkThemeName;
    GDK_BACKEND = "wayland,x11,*";
    XCURSOR_THEME = variant.cursorTheme;
    # XCURSOR_SIZE set separately in theme.nix
    QT_QUICK_CONTROLS_STYLE = "Kvantum";
    QT_QUICK_CONTROLS_MATERIAL_THEME = "Dark";
  };
in {
  inherit rosePineColors variants defaultVariant fonts commonPackages;
  inherit mkGtkCss mkSessionVariables;
}
