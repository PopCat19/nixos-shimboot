# AGENTS

**Purpose:** Reference document for LLM assistants working with this repository.

## Documentation Files

### DEVELOPMENT.md

Opinionated agent development rules and conventions. Covers:

- File headers and code style across multiple languages (Nix, Fish, Python, Bash, Rust, Go, TypeScript)
- Naming conventions and project structure
- Comments, navigation, and file hygiene
- DRY refactoring patterns
- Commit message format and workflow
- Documentation guidelines
- Validation and CI/CD configuration
- Principles (KISS, DRY, SoC, SRP, CoC, maintainable over clever)
- Vocabulary (DDD + Figma bridge, repo-agnostic definitions)

**Reading guide:** Comprehensive document (1.5~3k lines). Use the table of contents to navigate to relevant sections.

### SKILL.md

Condensed non-obvious conventions only. Assumes standard SWE practices. Covers:

- Naming (snake_case dirs, kebab-case files)
- Structure (depth limits, context.md requirements, module wiring, stratification thresholds)
- File headers (Purpose lines)
- Commit format and workflow
- Agent interaction patterns (one-shot commands, wl-copy wrapping)

**Reading guide:** Start here for quick reference. Fall back to DEVELOPMENT.md for detail.

### DEV-EXAMPLES.md

Concrete examples demonstrating conventions from DEVELOPMENT.md. Includes:

- File header patterns
- Code style transformations (flatten nesting, extract repeated values)
- Naming and structure examples
- Comment guidelines (what to keep vs. remove)
- DRY refactoring before/after examples
- Commit message format examples
- CI/CD workflow patterns

**Purpose:** Optional reference material for understanding rules in practice.

### context.md

Each directory with 5+ non-obvious files has a `context.md` listing every file with a one-line purpose. These derive from file header `Purpose:` lines and must stay in sync.

**Reading guide:** Check `context.md` to understand a directory's contents without opening each file.

## Scripts

### dev-conventions.sh

Unified CLI for all convention tooling. Entry point for changelog, sync, and lint commands.

**Usage:**
```bash
./conventions/dev-conventions.sh              # Interactive TUI (requires gum)
./conventions/dev-conventions.sh changelog    # Generate changelog and merge
./conventions/dev-conventions.sh sync         # Sync conventions from remote
./conventions/dev-conventions.sh lint         # Lint shell scripts
./conventions/dev-conventions.sh help
```

### src/changelog.sh

Generates changelog from git history before merge. Called via `dev-conventions.sh changelog`.

### src/sync.sh

Syncs convention files from remote repository to target projects. Called via `dev-conventions.sh sync`.

### src/lint.sh

Shell script linting and formatting (shfmt, shellcheck). Called via `dev-conventions.sh lint`.

### src/check-context.sh

Verifies `context.md` files match actual directory contents. Detects structural and content drift.

## Important Notice

**Do not revise these files unless explicitly requested by the user:**

- `DEVELOPMENT.md` — Established conventions for this project
- `DEV-EXAMPLES.md` — Reference examples tied to DEVELOPMENT.md rules
- `SKILL.md` — Condensed conventions derived from DEVELOPMENT.md
- `src/changelog.sh` — Workflow script following project conventions
- `src/sync.sh` — Workflow script following project conventions

**Repo-specific vocabulary mapping lives in the root `context.md`, not in
convention files. Do not add project paths to DEVELOPMENT.md or
SKILL.md.**

These files represent intentional design decisions. Modifications should only occur when the user explicitly states a need for changes.
