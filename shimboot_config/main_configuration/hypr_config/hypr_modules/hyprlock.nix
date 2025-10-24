# Hyprlock Configuration Module
#
# Purpose: Configure Hyprlock screen locker with Rose Pine theme
# Dependencies: None
# Related: keybinds.nix
#
# This module:
# - Sets up Hyprlock with Rose Pine color scheme
# - Configures clock, date, and password input
# - Defines lock screen appearance and behavior

{
  home.file.".config/hypr/hyprlock.conf".text = ''
    $base = 0xff191724
    $surface = 0xff1f1d2e
    $overlay = 0xff26233a
    $muted = 0xff6e6a86
    $subtle = 0xff908caa
    $text = 0xffe0def4
    $love = 0xffeb6f92
    $gold = 0xfff6c177
    $rose = 0xffebbcba
    $pine = 0xff31748f
    $foam = 0xff9ccfd8
    $iris = 0xffc4a7e7
    $highlightLow = 0xff21202e
    $highlightMed = 0xff403d52
    $highlightHigh = 0xff524f67

    general {
      hide_cursor = true
      grace = 1
      disable_loading_bar = true
    }

    background {
      color = $base
      blur_passes = 3
    }

    label {
      text = cmd[update:1000] date +"%H:%M"
      color = $text
      font_size = 120
      font_family = "JetBrainsMono Nerd Font, Inter, DejaVu Sans"
      position = 0, -120
      halign = center
      valign = center
    }

    label {
      text = cmd[update:1000] date +"%A, %B %d"
      color = $muted
      font_size = 22
      font_family = "Inter, JetBrainsMono Nerd Font, DejaVu Sans"
      position = 0, -30
      halign = center
      valign = center
    }

    input-field {
      monitor =
      size = 300, 44
      position = 0, 160
      halign = center
      valign = center

      rounding = 12
      outline_thickness = 2

      inner_color = $overlay
      outer_color = $highlightHigh
      font_color = $text

      placeholder_text = <i>password</i>
      fail_color = $love
      check_color = $iris
      capslock_color = $gold

      dots_size = 0.2
      dots_spacing = 0.25
    }
    label {
      text = "Type password to unlock"
      color = $subtle
      font_size = 14
      font_family = "Inter, JetBrainsMono Nerd Font, DejaVu Sans"
      position = 0, 210
      halign = center
      valign = center
    }
  '';
}
