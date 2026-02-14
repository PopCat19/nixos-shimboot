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
- Principles (KISS, DRY, maintainable over clever)

**Reading guide:** Comprehensive document (1.5~3k lines). Use the table of contents to navigate to relevant sections.

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

## Scripts

### generate-changelog.sh

Generates changelog from git history before merge.

**Usage:**
```bash
# Generate changelog before merge
./generate-changelog.sh --target main

# Rename after merge with actual commit hash
./generate-changelog.sh --rename
```

**Behavior:**
- Collects commits between target branch and current branch
- Archives existing root changelogs to `changelog-archive/`
- Generates `CHANGELOG-pending.md` with commit list and file changes
- After merge, renames with actual merge commit hash

## Important Notice

**Do not revise these files unless explicitly requested by the user:**

- `DEVELOPMENT.md` — Established conventions for this project
- `DEV-EXAMPLES.md` — Reference examples tied to DEVELOPMENT.md rules
- `generate-changelog.sh` — Workflow script following project conventions

These files represent intentional design decisions. Modifications should only occur when the user explicitly states a need for changes.
