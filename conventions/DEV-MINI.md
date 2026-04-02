# DEV-MINI

Purpose: Non-obvious conventions only. Assumes standard SWE practices. Principles: KISS, DRY, SoC, SRP, CoC. Vocabulary: Rule 21 in DEVELOPMENT.md.

## Naming

- Directories: `snake_case/`
- Files: `kebab-case.ext`
- Exceptions: ecosystem-mandated (`package.json`, `flake.nix`)

## Structure

- Max 6 levels deep from repo root (monorepo: from app root)
- Every module must be imported somewhere (wire in on create, remove refs before delete)
- Add `context.md` to folders with 5+ non-obvious files: one bullet per file, present-tense, no subdirectory entries (those get their own). Update in the same commit as any file addition, removal, or rename — treat drift as broken.
- **Single source of truth:** context.md entries derive from file header `Purpose:` lines. Files in context.md must have headers. The drift check validates both structure and content.
- **SoC:** One concern per directory. No catch-all dirs (`misc/`,
  `helpers/`). If a dir name doesn't declare a concern, rename or
  restructure.
- **SRP:** One reason to change per file. If two unrelated changes land in
  the same file across separate commits, split it.
- **CoC:** Conventions here are structural, not cosmetic. Follow by
  default; deviate only with documented reason.
- Files approaching 800–1000 lines: consider splitting by role (domain subdirs like `auth/login.nix`, `auth/tokens.nix`) or layer (layer subdirs like `api/types.ts`, `api/handlers.ts`). Existing structure rules (depth, wiring, context.md, headers) still apply. Scope: project source code only, not convention docs.

## Vocabulary

Prefer established terms when describing repo structure. Quick reference:

- **Domain** — bounded area of concern
- **Subdomain** — narrower concern within a domain
- **Bounded Context** — a deployable unit's scope — its own rules, its own reality
- **Context Boundary** — seam where unit-specific config meets shared config
- **Shared Kernel** — code no single domain owns but multiple use
- **Anti-Corruption Layer** — normalizes raw inputs before the rest of the system sees them
- **Factory** — constructs valid, complete objects from inputs
- **Entity** — a thing with identity, distinguished from others of its kind
- **Value Object** — a pure value, no identity, swappable and reusable
- **Aggregate** — pulls all parts of one entity into a coherent whole
- **Aggregate Root** — single entry point everything resolves through
- **Policy** — named rule set applied to entities
- **Specification** — defines what it means to satisfy a named policy
- **Strategy** — per-entity override of shared behavior; same interface, different implementation
- **Detached Instance** — a unit that opted out of shared behavior; owns its copy
- **Ubiquitous Language** — this vocabulary; full definitions at Rule 21 in DEVELOPMENT.md

**Repo-specific mapping:** Do not embed project paths here. Map terms to
your repo's actual structure in your root `context.md` under a
`## Vocabulary` section.

## Comments & Docs

- Discourage comments unless requested. Only keep: rationale, warnings, external refs
- No function docs unless requested
- No markdown docs unless requested
- Duplicate facts inline over cross-references
- No time markers ("as of 2024"), no priority markers

## Tone

- No first-person ("I", "we") in code, comments, or commits
- No emoticons unless requested
- Abbreviate: config, repo, temp, init

## File Headers

Essential. When used:
```
# <File Name>
#
# Purpose: <One-line present-tense intent>
#
# This module:
# - <Verb-led responsibility>
```

No dependency or relationship tracking in headers. Use inline comments at relevant code locations for critical relationships.

## Agent Interaction

One-shot commands: wrap output for `wl-copy` so it can be sent in one shot.
- Fish: `begin; <cmds>; end | wl-copy`
- Bash: `{ <cmds>; } | wl-copy`
- Use `begin; end` not `{ }` in fish. Use `$status` not `$?`.
- Always `--no-pager` on systemctl/journalctl. Use `timeout N` on blocking commands.
- Prefer `rg` (ripgrep) when available; fallback to `grep -r` if uncertain.
- Systemd is not universal — BSD, macOS, non-systemd Linux won't have `systemctl`. Don't assume it exists; check with `command -v systemctl` or skip if it errors.

## Commits

```
<type>(scope): <verb> <summary>
```

- Types: `feat` `fix` `refactor` `docs` `style` `test` `chore` `perf` `revert`
- Scope: basename, lowercase, max 3 words
- Summary: imperative, lowercase start, no period, max 72 chars
- Single-line only
- Append `[untested]` if validation skipped
- Append `[skip-check]` if intentionally bypassing checks

## Commit Workflow

- Stay in current branch unless explicitly told otherwise
- Commit iteratively (open-loop), squash after validation
- Squash only on experimental branches, never on shared branches
- Stage before Nix flake commands (`git add --intent-to-add .`)

## Validation

- Ask before running `nix flake check` (resource-intensive, CI typically handles it)
- Never commit failing checks without `[skip-check]` flag and documented reason
