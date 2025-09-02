{ pkgs, ... }:

{
  # Fonts configuration
  fonts.packages = with pkgs; [
    # Core fonts
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
    noto-fonts-emoji
    noto-fonts-extra

    # Fonts used by applications
    google-fonts  # Contains M+ Outline Fonts (Rounded Mplus 1c)
    jetbrains-mono  # Monospace font for terminals and coding
    nerd-fonts.jetbrains-mono  # JetBrains Mono with nerd font symbols
  ];

  fonts.fontconfig = {
    enable = true;
    defaultFonts = {
      serif = [
        "Rounded Mplus 1c Medium"
        "Noto Serif"
      ];
      sansSerif = [
        "Rounded Mplus 1c Medium"
        "Noto Sans"
      ];
      monospace = [
        "JetBrainsMono Nerd Font"
        "Noto Sans Mono"
      ];
      emoji = [ "Noto Color Emoji" ];
    };
  };
}