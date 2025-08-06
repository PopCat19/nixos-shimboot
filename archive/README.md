# Shimboot - NixOS Fork
> [Shimboot](https://github.com/ading2210/shimboot) is a collection of scripts for patching a Chrome OS RMA shim to serve as a bootloader for a standard Linux distribution. It allows you to boot a full desktop Debian install on a Chromebook, without needing to unenroll it or modify the firmware.

This is my work-in-progress fork of [ading2210](https://github.com/ading2210)'s [Shimboot](https://github.com/ading2210/shimboot). The goal here is to take the original, script-based build process and rewrite it with [Nix](https://nixos.org/) to make it fully declarative and reproducible.

This is a learning project for me. I'm still new to Nix, so I'm relying on documentation/forums and LLM guidance to figure things out. The main idea is to replace the shell scripts with a Nix flake that can build a complete, bootable shim image from (hopefully) a single command.

### Why Nix?
Nix was chosen for this project to ensure reproducibility. Cloning this repository and running `nix build` should produce the same result for anyone, regardless of their machine's configuration. In addition, Nix provides atomic builds that either succeed completely or fail cleanly. It also enforces declarative dependencies, tracking the entire dependency graph to improve understandability and maintainability.

### Project Roadmap & Status

````plaintext
[x] Project Scaffolding: Nix flake conversion complete.
[x] Patched systemd: mount_nofollow patch applied via overlay.
[x] Binary Cache: Cachix set up for patched systemd.
[x] FHS Rootfs Generation: buildEnv creates FHS-compliant rootfs.
[x] Final Image Assembly: build-final-image.sh automates build, supports recovery image for extra drivers/firmware.
[!] Hardware Testing:
    - systemd runs, kill-frecon service works, LightDM starts.
    - Hyprland is now the default session (not XFCE4).
    - Graphical session startup is broken: session PATH is missing core commands (mkdir, systemctl, Hyprland not found in session), so login fails after LightDM.
    - Next: fix session PATH and graphical login, ensure all required binaries are available in session.
[ ] Declarative Artifacts (future): Move manual extraction/patching in build-final-image.sh into pure Nix derivations for full reproducibility.
````

### How to Build (Current WIP State)
**This isn't ready for general use!** These instructions are for developers who want to follow along.
1.  **Prerequisites:** A working Nix installation with flakes enabled, and necessary build tools (`vboot_utils`, `binwalk`, etc.) installed system-wide.
2.  **Clone this repo** (specifically the `nixos` branch).
3.  **Get the Shim:** Download the official RMA shim for your board and place it at `./data/shim.bin`.
4.  **Build the Image:** Run `sudo ./scripts/build-final-image.sh`. This will build all components and create `shimboot_nixos.bin`.

### Project Credits
- [**ading2210**](https://github.com/ading2210) for the shimboot project and its derivatives.
- Feedback and assistance from those participating in the [original discussion](https://github.com/ading2210/shimboot/discussions/335).
- [**t3.chat**](https://t3.chat/) for providing useful LLMs for guidance.
