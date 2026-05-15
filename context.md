# Context

- `flake.nix` — Main flake entry point with core binary cache configuration
- `flake.lock` — Dependency lock file for reproducible builds
- `AGENTS.md` — Coordination guidelines for AI coding agents
- `README.md` — Detailed documentation of the shimboot build system

## Binary Caches

This flake defines several binary caches used during the ChromeOS system assembly:
- **Shimboot**: Optimized systemd and kernel-related components
- **Numtide**: Common development tools and utilities
