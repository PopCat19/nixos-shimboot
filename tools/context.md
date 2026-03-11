# tools/

- check-cachix.sh - Checks Cachix cache health and coverage
- cleanup-shimboot-rootfs.sh - Prunes old shimboot rootfs generations
- collect-minimal-logs.sh - Collects diagnostics from NixOS minimal rootfs
- compress-nix-store.sh - Compresses /nix/store with squashfs
- fetch-manifest.sh - Downloads ChromeOS recovery image chunks
- fetch-recovery.sh - Fetches ChromeOS recovery image hashes
- harvest-drivers.sh - Extracts ChromeOS kernel modules and firmware
- prune-firmware.sh - Prunes unused firmware files
- push-to-cachix.sh - Pushes Nix derivations to Cachix
- test-board-builds.sh - Tests Nix flake builds for ChromeOS boards
