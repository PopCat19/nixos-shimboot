
## Supported Boards

| Board | Arch | Kernel | Systemd |
|-------|------|--------|--------|
| snappy | Intel | 4.4.35 | 257 |
| grunt | AMD | 4.14.75 | 257 |
| octopus | Intel | 4.14.91 | 257 |
| hatch | Intel | 4.19.84 | 257 |
| dedede | Intel | 5.4.85 | 259 ✓ |
| zork | AMD | 5.4.85 | 259 ✗ |
| nissa | Intel | 5.15.74 | 260 |

Systemd version ceilings per board kernel.

- 257: kernel ≥ 3.15 ([systemd 257 README](https://github.com/systemd/systemd/blob/70b5d110be7702afc4dbce012f60d49506d513da/README#L45))
- 258/259: kernel ≥ 5.4 ([systemd 258 README](https://github.com/systemd/systemd/blob/v258/README), [systemd 259 README](https://github.com/systemd/systemd/blob/b3d8fc43e9cb531d958c17ef2cd93b374bc14e8a/README#L51))
- 260: kernel ≥ 5.10 ([systemd 260 README](https://github.com/systemd/systemd/blob/c0a5a2516d28601fb3afc1a77d7b42fcfe38fced/README#L58))

✓ = tested, ✗ = theoretical ceiling, untested.

The pinned systemd is built with unstable's stdenv for glibc compat ([d27b392/flake.nix#L60-L61](https://github.com/PopCat19/nixos-shimboot/blob/d27b392/flake.nix#L60-L61)), patched for ChromeOS kernel mount behavior ([d27b392/patches/systemd-mountpoint-util-chromeos.patch](https://github.com/PopCat19/nixos-shimboot/blob/d27b392/patches/systemd-mountpoint-util-chromeos.patch)), and supplemented with stub units and binaries for items nixos-unstable expects but 257.9 lacks ([d27b392/flake.nix#L86-L103](https://github.com/PopCat19/nixos-shimboot/blob/d27b392/flake.nix#L86-L103)).

Injected via `specialArgs`, not overlay, to avoid cross-version function argument issues ([d27b392/flake.nix#L254](https://github.com/PopCat19/nixos-shimboot/blob/d27b392/flake.nix#L254)).

Systemd 260 raised the minimum kernel baseline from 5.4 to 5.10 ([systemd 259 README](https://github.com/systemd/systemd/blob/b3d8fc43e9cb531d958c17ef2cd93b374bc14e8a/README#L51) vs [systemd 260 README](https://github.com/systemd/systemd/blob/c0a5a2516d28601fb3afc1a77d7b42fcfe38fced/README#L58)).

Dedede's 5.4 ChromeOS kernel meets 259's minimum but falls below 260's, which is why 259 works and 260 fails. The baseline bump also enabled switching from `O_PATH`/`mount_fd()` to the kernel 5.2+ new mount API (`open_tree`/`move_mount`), which the ChromeOS shim kernel lacks.

259.x is the ceiling. 258 and 259 tested working on dedede ([shimboot#405 (comment)](https://github.com/ading2210/shimboot/issues/405#issuecomment-4231104253)).


