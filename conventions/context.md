# Context

- `AGENTS.md` — Reference document for LLM assistants working with this repository
- `DEVELOPMENT.md` — Opinionated agent development rules and conventions
- `DEV-EXAMPLES.md` — Concrete examples demonstrating conventions in practice
- `SKILL.md` — Non-obvious conventions only, assumes standard SWE practices (moved to root)
- `dev-conventions.sh` — Unified CLI for development conventions tooling

## Vocabulary

DDD term mappings for this repo. Definitions at Rule 21 in
`conventions/DEVELOPMENT.md`.

| Term | This repo |
|------|-----------|
| **Aggregate Root** | `flake.nix` |
| **Domain** | `configuration/system/`, `configuration/home/` |
| **Subdomain** | `home/hyprland/`, `home/modules/` |
| **Bounded Context** | `configuration/hosts/<hostname>/` |
| **Context Boundary** | `hosts/*/user-config.nix` |
| **Shared Kernel** | `lib/` |
| **Anti-Corruption Layer** | `lib/mk-host.nix`, `lib/mk-home.nix` |
| **Factory** | `lib/mk-host.nix`, `lib/mk-home.nix` |
| **Repository** | `flake-modules/hosts.nix` |
| **Infrastructure** | `flake-modules/` |
| **Supporting Domain** | `tools/`, `conventions/` |
| **Generic Subdomain** | `overlays/` |
| **Base Domain** | `configuration/base/` |
| **Entity** | `configuration/hosts/<hostname>/` |
| **Value Object** | `configuration/stateversion.nix`, `configuration/user-config.nix` |
| **Aggregate** | `hosts/<hostname>/configuration.nix` |
| **Policy** | `configuration/profiles/*.nix` |
| **Specification** | `configuration/profiles/default.nix` |
| **Strategy** | `hosts/<hostname>/modules/*.nix` |
| **Detached Instance** | Any host-level `modules/` override |
| **Ubiquitous Language** | `conventions/DEVELOPMENT.md` Rule 21 + this table |
