# Hyprlock Configuration
#
# Purpose: Configure Hyprlock screen lock with Rosé Pine theme
# Dependencies: hyprlock, stylix
# Related: None
#
# This module:
# - Sets up lock screen with clock and date display
# - Configures password input field
# - Applies blur and hides cursor
# Note: Colors are managed by stylix Base16 scheme
{
  home.file.".config/hypr/hyprlock.conf".text = ''
    general {
      hide_cursor = true
      grace = 1
      disable_loading_bar = true
    }

    background {
      blur_passes = 3
    }

    label {
      text = cmd[update:1000] date +"%H:%M"
      font_size = 120
      font_family = "JetBrainsMono Nerd Font, Inter, DejaVu Sans"
      position = 0, -120
      halign = center
      valign = center
    }

    label {
      text = cmd[update:1000] date +"%A, %B %d"
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

      placeholder_text = <i>password</i>
      dots_size = 0.2
      dots_spacing = 0.25
    }

    label {
      text = "Type password to unlock"
      font_size = 14
      font_family = "Inter, JetBrainsMono Nerd Font, DejaVu Sans"
      position = 0, 210
      halign = center
      valign = center
    }
  '';
}
