# AGENTS

**Purpose:** Reference for LLM assistants working in this repository.

## Docs are code

This repo follows the [dev-mini](https://github.com/PopCat19/dev-conventions) conventions. The tree is self-documenting — directory names declare their concern. Module headers (`Purpose:` blocks) are the in-code documentation. Prefer `grep` over asking.

See `conventions/AGENTS.md` and `conventions/DEVELOPMENT.md` for the full rule set.

## README workflow

The README is generated from fragments. Never edit README.md directly.

```
readme_manifest/           # 13 numbered fragments, source-of-truth
tools/readme.sh sync       # fragments → README.md + validate refs
tools/readme.sh extract    # README.md → fragments (reverse)
tools/readme.sh check      # validate refs + citation drift (read-only)
tools/readme.sh all        # full pre-commit pass
```

Each fragment is raw markdown. The generator wraps specified fragments in `<details>`. Edits go in fragments, then `tools/readme.sh sync`.

## Key directories

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
| `tools/readme.sh` | Unified README workflow entry point |
| `manifests/` | ChromeOS shim chunk manifests per board |

## Conventions specific to this repo

- **Systemd ceiling:** Pinned to 257.9. Board table in `readme_manifest/03-boards.md` maps max version per kernel.
- **Cites require permalinks:** Every technical claim links to a commit-blob URL, not a relative path.
- **No em dashes:** Commas or sentence splits only.
- **Unicode symbols over emojis:** `✓ ✗` not `✅ ❌`.
- **One topic per line:** Split dense paragraphs at idea boundaries.
- **Informed over assumed:** Qualify unverified claims. A gap is better than a wrong explanation.
- **context.md files:** Check `*/context.md` to understand a directory's contents without opening each file.

## Important: Do not revise without explicit request

- `readme_manifest/*.md` — README fragments, source-of-truth
- `tools/generate-readme.sh` — Generator with auto-rebase logic
- `tools/readme-to-fragments.sh` — Reverse extraction with validation
- `tools/check-refs.sh` — Reference validation checker
- `tools/check-readme-drift.sh` — Citation drift detector
- `conventions/DEVELOPMENT.md` — Project conventions
- `flake.nix` — Flake configuration
