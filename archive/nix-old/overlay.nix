# ./nix/overlay.nix
# This is a function that takes the final and previous package sets.
(final: prev: {
  # We are modifying the 'systemd' package.
  systemd = prev.systemd.overrideAttrs (oldAttrs: {
    # Add our patch to the list of existing patches.
    patches = (oldAttrs.patches or []) ++ [
      ../nix/patches/systemd_unstable.patch
    ];
  });
})
