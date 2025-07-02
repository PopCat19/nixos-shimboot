# Shimboot - NixOS Fork
> [Shimboot](https://github.com/ading2210/shimboot) is a collection of scripts for patching a Chrome OS RMA shim to serve as a bootloader for a standard Linux distribution. It allows you to boot a full desktop Debian install on a Chromebook, without needing to unenroll it or modify the firmware.

This is my work-in-progress fork of [ading2210](https://github.com/ading2210)'s [Shimboot](https://github.com/ading2210/shimboot). The goal here is to take the original, script-based build process and rewrite it with [Nix](https://nixos.org/) to make it fully declarative and reproducible.

This is a learning project for me. I'm still new to Nix, so I'm relying on documentation/forums and LLM guidance to figure things out. The main idea is to replace the shell scripts with a Nix flake that can build a complete, bootable shim image from (hopefully) a single command.

### Why Nix?
Nix was chosen for this project to ensure reproducibility. Cloning this repository and running `nix build` should produce the same result for anyone, regardless of their machine's configuration. In addition, Nix provides atomic builds that either succeed completely or fail cleanly. It also enforces declarative dependencies, tracking the entire dependency graph to improve understandability and maintainability.

### Project Roadmap & Status

Here's a breakdown of the project's progress:

-   [x] **Project Scaffolding:** Converted the project to use a Nix flake.
-   [x] **Patched `systemd`:** Successfully applied the `mount_nofollow` patch using a Nix overlay.
-   [x] **Binary Cache:** A Cachix cache ([shimboot-systemd-nixos](https://app.cachix.org/cache/shimboot-systemd-nixos)) is set up to host the patched `systemd`.
-   [x] **FHS Rootfs Generation:** The `rootfs` is now built using `buildEnv`, creating a proper Filesystem Hierarchy Standard (FHS) directory structure.
-   [x] **Final Image Assembly:** The `build-final-image.sh` script automates the entire build and assembly process.
-   [?] **Testing on Hardware:**
    -   **Status:** SystemD runs with `kill-frecon` service to render graphics.
    -   **Details:** The patched `systemd` runs without errors, with `kill-freecon` service to switch virtual terminal for graphical session; no tty though.
    -   **Current Issue:** LightDM is present and working, but XFCE4 is crashing, likely due to bad linkage (can't find `cat`, `sleep`, `xfce4-session-4.20.2/etc/xdg/xfce4/xinitrc: line <num>: <cmd> command not found`).
    -   **Next Steps:** Troubleshoot the XFCE4 issue, possibly comparing configurations with the original Shimboot XFCE4 setup.
-   [ ] **Declarative Artifacts (Future Goal):** The manual extraction and patching steps in `build-final-image.sh` should eventually be moved into pure, hashed Nix derivations for better reproducibility and maintainability.

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
