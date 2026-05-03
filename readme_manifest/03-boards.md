
## Supported Boards

| Board | Arch | Kernel | Systemd |
|-------|------|--------|--------|
| snappy | Intel | 4.4.35 | 257.x |
| grunt | AMD | 4.14.75 | 257.x |
| octopus | Intel | 4.14.91 | 257.x |
| hatch | Intel | 4.19.84 | 257.x |
| dedede | Intel | 5.4.85 | 258 ✓ · 259 ✓ |
| zork | AMD | 5.4.85 | 257.x |
| nissa | Intel | 5.15.74 | 258 ✗ |

Systemd is pinned to 257.9 via a separate `nixpkgs` input, locked to a commit before the 258 bump ([d27b392/flake.nix#L20](https://github.com/PopCat19/nixos-shimboot/blob/d27b392/flake.nix#L20)).

The pinned systemd is built with unstable's stdenv for glibc compat ([d27b392/flake.nix#L60-L61](https://github.com/PopCat19/nixos-shimboot/blob/d27b392/flake.nix#L60-L61)), patched for ChromeOS kernel mount behavior ([d27b392/patches/systemd-mountpoint-util-chromeos.patch](https://github.com/PopCat19/nixos-shimboot/blob/d27b392/patches/systemd-mountpoint-util-chromeos.patch)), and supplemented with stub units and binaries for items nixos-unstable expects but 257.9 lacks ([d27b392/flake.nix#L86-L103](https://github.com/PopCat19/nixos-shimboot/blob/d27b392/flake.nix#L86-L103)).

Injected via `specialArgs`, not overlay, to avoid cross-version function argument issues ([d27b392/flake.nix#L254](https://github.com/PopCat19/nixos-shimboot/blob/d27b392/flake.nix#L254)).

Systemd 260 raised the kernel baseline to 5.10 and switched from `O_PATH`/`mount_fd()` to `open_tree()`/`move_mount()`, which fails on dedede's 5.4 ChromeOS kernel. 259.x is the ceiling. 258 and 259 tested working on dedede ([shimboot#405 (comment)](https://github.com/ading2210/shimboot/issues/405#issuecomment-4231104253)).


