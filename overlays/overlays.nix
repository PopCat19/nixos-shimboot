# Architecture-aware overlays
_system: [
  # Custom packages overlay

  # Import overlays
  # Pinned systemd 258.3 with ChromeOS patches
  (import ./systemd-258.3.nix)

  # Rosé Pine full GTK theme (Main & Moon variants with icons)
  (import ./rose-pine-gtk-theme-full.nix)
]
