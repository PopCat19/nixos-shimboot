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
./conventions/generate-changelog.sh --target main

# Rename after merge with actual commit hash
./conventions/generate-changelog.sh --rename
```

**Behavior:**
- Collects commits between target branch and current branch
- Archives existing root changelogs to `changelog_archive/`
- Generates `CHANGELOG-pending.md` with commit list and file changes
- After merge, renames with actual merge commit hash

### sync-conventions.sh

Syncs convention files from remote repository to target projects.

**Usage:**
```bash
# Pull latest from main (default)
./conventions/sync-conventions.sh

# Pull specific version
./conventions/sync-conventions.sh --version v1.2.0

# Pull from custom remote/branch
./conventions/sync-conventions.sh --remote https://github.com/myfork/dev-conventions --branch dev

# Pull specific files only
./conventions/sync-conventions.sh --files conventions/AGENTS.md,conventions/DEVELOPMENT.md

# Preview changes without writing
./conventions/sync-conventions.sh --dry-run
```

**Behavior:**
- Fetches files from GitHub raw content URLs
- Compares with existing files, skips unchanged
- Stages updates for git review (does not auto-commit)

## Important Notice

**Do not revise these files unless explicitly requested by the user:**

- `DEVELOPMENT.md` — Established conventions for this project
- `DEV-EXAMPLES.md` — Reference examples tied to DEVELOPMENT.md rules
- `generate-changelog.sh` — Workflow script following project conventions
- `sync-conventions.sh` — Workflow script following project conventions

These files represent intentional design decisions. Modifications should only occur when the user explicitly states a need for changes.
