# Architecture-aware overlays
_system: [
  # Custom packages overlay

  # Import overlays
  # Rosé Pine full GTK theme (Main & Moon variants with icons)
  (import ./rose-pine-gtk-theme-full.nix)

  # Nix: skip functional tests (fail on devices with sandboxing disabled)
  (_final: _prev: {
    nix = _prev.nix.overrideAttrs (_: {
      doCheck = false;
    });
  })
]
