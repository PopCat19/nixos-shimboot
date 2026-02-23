# DEV-MINI

Purpose: Non-obvious conventions only. Assumes standard SWE practices.

## Naming

- Directories: `snake_case/`
- Files: `kebab-case.ext`
- Exceptions: ecosystem-mandated (`package.json`, `flake.nix`)

## Structure

- Max 6 levels deep from repo root (monorepo: from app root)
- Every module must be imported somewhere (wire in on create, remove refs before delete)

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
