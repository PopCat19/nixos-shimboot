# AGENTS.md

## Project overview

Boot NixOS on locked ChromeOS devices via the RMA shim vulnerability. Flake-based build system + ChromeOS hardware abstraction layer. Read `README.md` for the human-facing overview; this file is the agent-facing complement.

The repo follows [dev-mini](https://github.com/PopCat19/dev-conventions) conventions. See `conventions/AGENTS.md` and `conventions/DEVELOPMENT.md` for the full rule set.

## Setup commands

```bash
# Enter dev shell
nix develop

# Stage before any flake command (Nix flakes read from git tree)
git add --intent-to-add .
```

## Build commands

```bash
# Build a shimboot image for a board
sudo ./tools/build/assemble-final.sh --board dedede --rootfs base

# Write to USB
sudo ./tools/write/write-shimboot-image.sh
```

## README workflow

Never edit `README.md` directly — it is generated from fragments.

```bash
tools/readme.sh sync       # fragments → README.md + validate refs
tools/readme.sh extract    # README.md → fragments (reverse edit)
tools/readme.sh check      # validate refs + citation drift (read-only)
tools/readme.sh all        # full pre-commit: sync + check
```

Edits go in `readme_manifest/*.md`, then run `tools/readme.sh sync`.

## Code style

Module headers serve as in-code documentation. Every file with a `Purpose:` line is self-documenting. `context.md` files (one per directory with 5+ files) derive from these headers and must stay in sync.

Repo-specific rules:

- **Cites require permalinks** — link to commit-blob URLs, not relative paths
- **No em dashes** — commas or sentence splits only
- **Unicode symbols over emojis** — `✓ ✗` not `✅ ❌`
- **One topic per line** — split dense paragraphs at idea boundaries
- **Informed over assumed** — qualify unverified claims. A gap is better than a wrong explanation.

## Testing

```bash
# Validate all markdown file references point to existing files
tools/check-refs.sh

# Detect stale commit citations in README
tools/check-readme-drift.sh

# Full validation pass (read-only)
tools/readme.sh check
```

## Key directories

Explore by directory name — the tree is self-documenting:

| Directory | Concern |
|-----------|---------|
| `flake.nix` | Exports `nixosModules.chromeos`, packages, devShells |
| `flake_modules/` | Image building, kernel extraction, system configs |
| `shimboot_config/base_configuration/` | ChromeOS base system (boot, fs, hw, users) |
| `shimboot_config/boards/` | Per-board hardware database |
| `bootloader/` | Initramfs bootstrap menu (`bootstrap.sh`) |
| `patches/` | systemd ChromeOS mount patch |
| `tools/build/` | Image assembly (`assemble-final.sh`), driver harvesting |
| `tools/write/` | Safe USB flashing |
| `tools/rescue/` | Boot troubleshooting, chroot recovery |
| `manifests/` | ChromeOS shim chunk manifests per board |

## Guarded files

Do not revise without explicit request:

- `readme_manifest/*.md`
- `tools/generate-readme.sh`, `tools/readme-to-fragments.sh`
- `tools/check-refs.sh`, `tools/check-readme-drift.sh`
- `conventions/DEVELOPMENT.md`
- `flake.nix`
