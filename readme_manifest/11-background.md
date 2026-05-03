This project uses a flake-based approach over the original [ading2210/shimboot](https://github.com/ading2210/shimboot) scripts, which expect a FHS-compliant build host (Debian). Nix flakes with `raw-efi` image building provide reliable, declarative image generation on NixOS.

Earlier attempts, [nixos-shimboot-legacy](https://github.com/PopCat19/nixos-shimboot-legacy/tree/qemu-method2) and [shimboot-nixos](https://github.com/PopCat19/shimboot-nixos), produced fragile, semi-bootable images. This repo was started fresh to avoid inherited complexity.

**Why NixOS:** While not the lightest distro for low-end Chromebook hardware, NixOS provides reproducible, declarative system configuration.

The same flake that builds the image also serves as the device's runtime configuration.

Users unfamiliar with Nix should try it in a VM first ([nixos.org/download](https://nixos.org/download)).


