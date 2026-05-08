## Roadmap

### Done

- [x] Builds without flake errors
- [x] Bootable NixOS via RMA shim
- [x] Multi-board compatibility (Intel/AMD, ARM theoretical)
- [x] Functional networking, Hyprland, user environment
- [x] Per-board hardware database with conditional config
- [x] Kill-frecon graphics handoff
- [x] `nixos-rebuild` support (requires `--option sandbox false` on older kernels)
- [x] NixOS generation selector in bootstrap menu
- [x] Battery SoC in bootstrap menu
- [x] Expand rootfs to fill USB
- [x] Export `nixosModules.chromeos` as hardware abstraction layer
- [x] GitHub CI with caching
- [x] ZRAM
- [x] LUKS2 encryption (passphrase, keyfile, rescue tooling)

### Pending

- [ ] SDDM greeter support (blank backlit screen after kill-frecon)
- [ ] XDG redirect fixes
- [ ] bwrap/Steam workaround validation ([untested](readme_manifest/09-bwrap-workaround.md))
- [ ] ARM board testing
- [ ] Audio for non-octopus/snappy boards
- [ ] Refine and cleanup base configuration
- [ ] Upstream systemd 258+ integration (dedede ceiling is 259)
