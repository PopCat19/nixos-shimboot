# Architecture-aware overlays
system:
  # Pinned systemd 258.3 with ChromeOS patches (resolves against super to break cycle)
  (import ./systemd-overlay.nix system)
  ++ [
    # Rosé Pine full GTK theme (Main & Moon variants with icons)
    (import ./rose-pine-gtk-theme-full.nix)
  ]
