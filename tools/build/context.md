# Context

- assemble-final.sh — Builds final shimboot image with Nix outputs and partitioning
- harvest-drivers.sh — Harvests out-of-tree drivers into image
- compress-nix-store.sh — Compresses Nix store for inclusion
- prune-firmware.sh — Prunes firmware for target board
- fetch-manifest.sh — Fetches build manifest from remote
- fetch-recovery.sh — Fetches recovery image
- check-cachix.sh — Checks Cachix for cached artifacts
- push-to-cachix.sh — Pushes build outputs to Cachix
- test-board-builds.sh — Tests builds for target boards
