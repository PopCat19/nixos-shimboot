{ pkgs, ... }:

{
  # **INPUT METHOD CONFIGURATION**
  # Configures Fcitx5 for input methods with full Wayland support.
  i18n.inputMethod = {
    type = "fcitx5";
    enable = true;
    fcitx5.addons = with pkgs; [
      libsForQt5.fcitx5-qt # Qt module.
      fcitx5-gtk
      fcitx5-mozc # Mozc input method engine for Japanese.
      fcitx5-rose-pine # Rose Pine theme for fcitx5.
    ];
  };

  # fcitx5 Rose Pine theme configuration
  home.file.".config/fcitx5/conf/classicui.conf".text = ''
    # Vertical Candidate List
    Vertical Candidate List=False
    # Use Per Screen DPI
    PerScreenDPI=True
    # Use mouse wheel to go to prev or next page
    WheelForPaging=True
    # Font
    Font="Rounded Mplus 1c Medium 11"
    # Menu Font
    MenuFont="Rounded Mplus 1c Medium 11"
    # Tray Font
    TrayFont="Rounded Mplus 1c Medium 11"
    # Tray Label Outline Color
    TrayOutlineColor=#000000
    # Tray Label Text Color
    TrayTextColor=#ffffff
    # Prefer Text Icon
    PreferTextIcon=False
    # Show Layout Name In Icon
    ShowLayoutNameInIcon=True
    # Use input method language to display text
    UseInputMethodLangaugeToDisplayText=True
    # Rose Pine Theme
    Theme=rose-pine
    # Dark Theme
    DarkTheme=rose-pine
    # Follow system light/dark color scheme
    UseDarkTheme=True
    # Use accent color
    UseAccentColor=True
    # Use system tray icon
    EnableTray=True
    # Show preedit in application
    ShowPreeditInApplication=False
  '';

  # Manually link fcitx5 rose pine themes to user directory
  home.file.".local/share/fcitx5/themes/rose-pine".source =
    "${pkgs.fcitx5-rose-pine}/share/fcitx5/themes/rose-pine";
  home.file.".local/share/fcitx5/themes/rose-pine-dawn".source =
    "${pkgs.fcitx5-rose-pine}/share/fcitx5/themes/rose-pine-dawn";
  home.file.".local/share/fcitx5/themes/rose-pine-moon".source =
    "${pkgs.fcitx5-rose-pine}/share/fcitx5/themes/rose-pine-moon";
}