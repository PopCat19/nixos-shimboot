# DEVELOPMENT

**Purpose:** An opinionated agent development rules and conventions.

**Principles:** KISS (Keep It Simple, Stupid), DRY (Don't Repeat Yourself), lazy maintenance, self-documenting code.

**Reading Guide:** This document is comprehensive (1.5~3k lines) covering multiple languages and use cases. Use the table of contents to navigate to relevant sections. Each rule is independently simple; apparent complexity comes from breadth of coverage. Rule 17 (Example Patterns) is optional reference material.

## Table of Contents

1. [File Headers](#1-file-headers)
2. [Code Style](#2-code-style)
3. [Naming](#3-naming)
4. [Structure](#4-structure)
5. [Comments](#5-comments)
6. [Navigation](#6-navigation)
7. [File Hygiene](#7-file-hygiene)
8. [User-Configurable Files](#8-user-configurable-files)
9. [DRY Refactoring](#9-dry-refactoring)
10. [Commit Messages](#10-commit-messages)
11. [Commit Workflow](#11-commit-workflow)
12. [Documentation](#12-documentation)
13. [Validation](#13-validation)
14. [CI/CD Configuration](#14-cicd-configuration)
15. [Principles](#15-principles)
16. [Tone and Formatting](#16-tone-and-formatting)
17. [Example Patterns](#17-example-patterns)
18. [New Rule Files](#18-new-rule-files)
19. [Changelog Policy](#19-changelog-policy)

## 1. File Headers

**Rationale:** Headers provide quick context without opening files. Minimal format avoids maintenance overhead from tracking dependencies and relationships that change frequently.

**Policy:** Optional unless project specifies. When used:

```
# <File Name>
#
# Purpose: <One-line functional intent>
#
# This module:
# - <Verb-led responsibility>
# - <Verb-led responsibility>
```

**Guidelines:**
- **Purpose:** Declarative, present tense, one line. Describes *what* the module does.
  - Good: `Manages user authentication tokens`
  - Bad: `This file will handle tokens` (not present tense, unclear)
- **Bullets:** Verb-led, max 5, distinct responsibilities.
  - Good: `Validates JWT signatures`, `Refreshes expired tokens`
  - Bad: `Token stuff`, `Handles authentication` (too vague)

**Why minimal:**
- Dependencies visible in code (use `grep -r "import" file.js` to find)
- Related files found via git history (`git log --follow --all -- *pattern*`)
- Avoids staleness from refactoring, renames, deletions
- Less to maintain = more likely to stay accurate

**Function documentation:**
- Document only if explicitly requested
- Increases maintenance burden
- Code should self-document when possible

**Portable scripts exception:**
- Self-contained scripts (distributed standalone) may include:
  - Extended header with usage examples
  - `--help`/`-h` flag handler
  - Options documentation
- **Why:** No external docs available; script must be self-explanatory
- **Trade-off:** Maintenance burden for portability
- **Rule:** User must explicitly request this level of documentation

**For critical relationships:** Add inline comments at relevant code locations:
```javascript
// When modifying token expiry logic, also update:
// - auth-cache.js (cache TTL must match)
// - session-store.js (cleanup interval)
```

## 2. Code Style

**Rationale:** Consistency reduces cognitive load. Automated tools catch errors and maintain standards without manual review.

**Policy:** Defer to project LSP/linter (e.g. RFC 166, alejandra, prettier, biome).

### Universal Rules

- **Line width:** Default 100, context-specific exceptions
  - Code: 100 characters (readable on split screens)
  - Commit summaries: 72 characters (git log readability, see Rule 10)
  - Python with black: 88 characters (tool default)
  - Exception: Long hashes, URLs, Nix store paths
- **Trailing newline:** Single at EOF (POSIX compliance, cleaner diffs)
- **Extract repeated values:** Named bindings for duplicates
  - Before: `timeout: 5000` appears 6 times
  - After: `const TIMEOUT_MS = 5000`
- **Flatten nesting:** Reduce unnecessary indentation
  - Before: `if (a) { if (b) { if (c) { ... }}}`
  - After: `if (!a) return; if (!b) return; if (!c) return; ...`
- **No first-person:** Avoid "I", "we" in code, comments, and commit messages
  - Use `# Validates here because...` not `# We validate here because...`
  - Use `fix: update API endpoint` not `fix: we updated the API`

### Nix (NixOS, Home Manager, Flakes)

**Formatter:** `nixfmt` (RFC 166, merged as default)

**Critical:** Nix flakes read from git tree, not working directory. Always stage files before validation.

```bash
# Stage new files with intent-to-add (allows flake to see them)
git add --intent-to-add .

# Or actually stage
git add .

# Then validate
nix flake check
```

**Why:** Unstaged files are invisible to `nix flake check` and other flake commands. This causes confusing "file not found" errors.

**Conventions:**
- Use `let...in` for local bindings
  ```nix
  let
    version = "1.2.3";
    src = fetchFromGitHub { inherit version; ... };
  in
  mkDerivation { inherit src version; }
  ```
- Prefer `inherit` over explicit assignment when names match
  ```nix
  # Good
  { lib, stdenv, fetchurl }:
  mkDerivation {
    inherit stdenv;
    pname = "example";
  }

  # Bad
  mkDerivation {
    stdenv = stdenv;
  }
  ```
- List attribute sets alphabetically (except `name`/`pname` first)
- Use `with` sparingly (only for large scopes like `pkgs`)
- Flake outputs: follow standard schema (`packages`, `devShells`, `nixosConfigurations`)
- Pin inputs with `follows` to avoid duplication
  ```nix
  inputs.home-manager.inputs.nixpkgs.follows = "nixpkgs";
  ```
- Extract large attribute sets to separate files
  ```nix
  # Bad: 200-line packages list inline

  # Good
  packages = import ./packages.nix { inherit pkgs; };
  ```

### Fish Shell

**Conventions:**
- Use `set -l` for local variables, `set -g` for global
  ```fish
  set -l temp_file (mktemp)
  set -g API_KEY "..."
  ```
- Prefer `string` built-ins over external tools
  ```fish
  # Good
  set filename (string replace '.txt' '.md' $input)

  # Bad
  set filename (echo $input | sed 's/.txt/.md/')
  ```
- Use command substitution `(command)` syntax
  ```fish
  set result (command args)
  ```
- Test conditions with `test` or `[`
  ```fish
  if test -f $file
      echo "exists"
  end
  ```
- Functions over scripts when possible (enables autoloading)
  - **Autoloading requirement:** Functions must live in `~/.config/fish/functions/` with matching filename
  - Example: `~/.config/fish/functions/my_func.fish` for `function my_func`
- Status checks: use `$status` immediately after command
  ```fish
  command
  if test $status -eq 0
      echo "success"
  end
  ```

### Python

**Formatter:** `black` or `ruff format`
**Linter:** `ruff` or `pylint`

**Conventions:**
- Follow PEP 8
  - Line length: 88 (black default) or 100
  - Imports: stdlib, external, local (separated by blank line)
- Type hints for function signatures
  ```python
  def process(data: str, timeout: int = 30) -> Result:
      return parse(data)
  ```
- F-strings over `.format()` or `%`
  ```python
  message = f"User {name} logged in at {time}"
  ```
- List comprehensions over `map`/`filter` when readable
  ```python
  evens = [x for x in numbers if x % 2 == 0]
  ```
- Context managers for resources
  ```python
  with open(path) as f:
      content = f.read()
  ```
- Virtual environments for dependencies
  ```bash
  python -m venv .venv
  source .venv/bin/activate
  ```
- Error handling with specific exceptions
  ```python
  try:
      data = load_config(path)
  except FileNotFoundError:
      logger.error(f"Config not found: {path}")
      raise
  except json.JSONDecodeError as e:
      logger.error(f"Invalid JSON: {e}")
      raise ConfigError(f"Parse failed: {path}") from e
  ```

### Bash

**Formatter:** `shfmt` (https://github.com/mvdan/sh)
**Linter:** `shellcheck`

**Conventions:**
- Use `#!/usr/bin/env bash` shebang
- Set strict mode at top of scripts
  ```bash
  set -Eeuo pipefail
  ```
- Quote all variable expansions unless word-splitting intended
  ```bash
  echo "$var"           # Quoted
  array=($list)         # Exception: intentional splitting
  ```
- Use `[[ ]]` for tests (not `[ ]`)
  ```bash
  if [[ -f "$file" && "$var" == "value" ]]; then
  	echo "match"
  fi
  ```
- Use `local` for function variables
  ```bash
  function process() {
  	local temp_file=$(mktemp)
  	# ...
  }
  ```
- Prefer `$()` over backticks for command substitution
  ```bash
  result=$(command)
  ```
- Check command existence before use
  ```bash
  if ! command -v jq &> /dev/null; then
  	echo "jq not found"
  	exit 1
  fi
  ```

### Rust

**Formatter:** `rustfmt` (automatic via `cargo fmt`)
**Linter:** `clippy` (run via `cargo clippy`)

**Conventions:**
- Use `Result<T, E>` for fallible operations
  ```rust
  fn parse_config(path: &str) -> Result<Config, ConfigError> {
      let contents = std::fs::read_to_string(path)?;
      serde_json::from_str(&contents)
          .map_err(ConfigError::ParseError)
  }
  ```
- Avoid `unwrap()` and `expect()` in production code
  ```rust
  // Bad (panics on None)
  let value = map.get("key").unwrap();

  // Good
  let value = map.get("key").ok_or(Error::MissingKey)?;

  // Good (with context)
  let value = map.get("key")
      .ok_or_else(|| Error::MissingKey("key".into()))?;
  ```
- Prefer `match` for exhaustive handling
  ```rust
  match result {
      Ok(value) => process(value),
      Err(e) => {
          log::error!("Failed to process: {}", e);
          return Err(e.into());
      }
  }
  ```
- Use `?` operator for error propagation
  ```rust
  fn process() -> Result<(), Error> {
      let data = fetch_data()?;
      let parsed = parse(data)?;
      store(parsed)?;
      Ok(())
  }
  ```
- Implement `From` for error conversions
  ```rust
  impl From<std::io::Error> for MyError {
      fn from(err: std::io::Error) -> Self {
          MyError::Io(err)
      }
  }
  ```
- Use lifetimes explicitly when needed
  ```rust
  // Explicit lifetime when struct holds references
  struct Config<'a> {
      name: &'a str,
      path: &'a Path,
  }
  ```
- Prefer `impl Trait` for return types
  ```rust
  fn get_items() -> impl Iterator<Item = String> {
      vec!["a", "b", "c"]
          .into_iter()
          .map(String::from)
  }
  ```
- Use `derive` macros liberally
  ```rust
  #[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
  struct User {
      id: u64,
      name: String,
  }
  ```
- Organize imports with `use` groups
  ```rust
  // Standard library
  use std::collections::HashMap;
  use std::fs;

  // External crates
  use serde::{Deserialize, Serialize};
  use tokio::runtime::Runtime;

  // Internal modules
  use crate::config::Config;
  use crate::errors::Error;
  ```

### Go

**Formatter:** `gofmt` or `goimports` (automatic)
**Linter:** `golangci-lint`

**Conventions:**
- Early returns for error checking
  ```go
  func process(data string) error {
      if data == "" {
          return errors.New("empty data")
      }

      result, err := parse(data)
      if err != nil {
          return fmt.Errorf("parse failed: %w", err)
      }

      return store(result)
  }
  ```
- Use `defer` for cleanup
  ```go
  func readFile(path string) ([]byte, error) {
      f, err := os.Open(path)
      if err != nil {
          return nil, err
      }
      defer f.Close()  // Cleanup guaranteed

      return io.ReadAll(f)
  }
  ```
- Interfaces for abstraction
  ```go
  // Small, focused interfaces
  type Reader interface {
      Read(p []byte) (n int, err error)
  }

  // Accept interfaces, return structs
  func NewProcessor(r Reader) *Processor {
      return &Processor{reader: r}
  }
  ```
- Table-driven tests
  ```go
  func TestValidate(t *testing.T) {
      tests := []struct {
          name    string
          input   string
          wantErr bool
      }{
          {"empty", "", true},
          {"valid", "test@example.com", false},
          {"invalid", "not-an-email", true},
      }

      for _, tt := range tests {
          t.Run(tt.name, func(t *testing.T) {
              err := Validate(tt.input)
              if (err != nil) != tt.wantErr {
                  t.Errorf("got error %v, wantErr %v", err, tt.wantErr)
              }
          })
      }
  }
  ```
- Error wrapping with `%w`
  ```go
  if err != nil {
      return fmt.Errorf("failed to process user %s: %w", userID, err)
  }
  ```
- Context for cancellation and timeouts
  ```go
  func fetch(ctx context.Context, url string) (*Response, error) {
      req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
      if err != nil {
          return nil, err
      }
      // Request respects context deadline/cancellation
      return client.Do(req)
  }
  ```
- Package organization
  ```
  myproject/
  ├── cmd/              # Main applications
  │   └── myapp/
  │       └── main.go
  ├── internal/         # Private application code
  │   ├── config/
  │   └── database/
  ├── pkg/              # Public library code
  │   └── client/
  └── go.mod
  ```
- Zero values are useful
  ```go
  // Structs with sensible zero values don't need constructors
  var buf bytes.Buffer  // Ready to use
  buf.WriteString("hello")
  ```
- Use named return values for clarity (sparingly, with explicit returns)
  ```go
  func divide(a, b float64) (result float64, err error) {
      if b == 0 {
          return 0, errors.New("division by zero")
      }
      result = a / b
      return result, nil  // Explicit for clarity
  }
  ```
  - **Note:** Bare `return` can obscure what's being returned; explicit is clearer

### Bun/TypeScript/JavaScript

**Formatter:** `biome` or `prettier`
**Linter:** `biome` or `eslint`

**Conventions:**
- Use `const` by default, `let` when reassignment needed, never `var`
  ```typescript
  const API_URL = "https://api.example.com";
  let counter = 0;
  ```
- Prefer arrow functions for callbacks
  ```typescript
  items.map((item) => item.name)
  ```
- Use template literals over concatenation
  ```typescript
  console.log(`User ${name} logged in`)
  ```
- Optional chaining and nullish coalescing
  ```typescript
  const name = user?.profile?.name ?? "Anonymous"
  ```
- Async/await over raw promises
  ```typescript
  const response = await fetch(url);
  const data = await response.json();
  ```
- Destructure function parameters for readability
  ```typescript
  function createUser({ name, email, role = "user" }) {
      // ...
  }
  ```
- Type annotations for public APIs
  ```typescript
  export function validate(input: string): boolean {
      return input.length > 0
  }
  ```
- Early returns over nested conditions
  ```typescript
  function process(data) {
      if (!data) return null
      if (data.invalid) return null
      return transform(data)
  }
  ```

### Error Handling (All Languages)

**Principles:**
- Fail fast and explicitly (no silent failures)
- Return/throw errors with context
- Distinguish recoverable vs fatal errors

See per-language sections above for idiomatic patterns.

### Testing Conventions

**File naming:**
- Nix: `test.nix` or `default.nix` in `tests/` dir
- Fish: `test_function_name.fish` in `tests/`
- Rust: `mod tests` block in same file, or `tests/` dir for integration tests
- Go: `module_test.go` alongside source
- Bun: `module.test.ts` alongside source

**Structure:**
```typescript
// Bun test example
import { test, expect } from "bun:test"

test("validates empty email returns error", () => {
    const result = validate("")
    expect(result.ok).toBe(false)
})
```

```fish
# Fish test example
function test_parse_empty_string
    set result (parse_config "")
    test $status -ne 0
    or return 1
end
```

```rust
// Rust test example
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_validate_empty_email_returns_error() {
        let result = validate("");
        assert!(result.is_err());
    }

    #[test]
    fn test_validate_correct_email_succeeds() {
        let result = validate("test@example.com");
        assert!(result.is_ok());
    }
}
```

```go
// Go test example (table-driven)
func TestValidate(t *testing.T) {
    tests := []struct {
        name    string
        input   string
        wantErr bool
    }{
        {"empty", "", true},
        {"valid", "test@example.com", false},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            err := Validate(tt.input)
            if (err != nil) != tt.wantErr {
                t.Errorf("got error %v, wantErr %v", err, tt.wantErr)
            }
        })
    }
}
```

**Principles:**
- Arrange-Act-Assert pattern
- Descriptive names: `test_<function>_<scenario>_<expected>`
- One logical assertion per test
- Mock external dependencies

### Security

- Never commit secrets (use agenix for secret management when appropriate)
  ```nix
  # Use agenix for secrets
  age.secrets.api-key = {
    file = ./secrets/api-key.age;
    owner = "myuser";
  };

  # Reference in config
  services.myapp.apiKeyFile = config.age.secrets.api-key.path;
  ```
- Validate input at boundaries
  ```typescript
  // Sanitize before use
  const cleanInput = input.trim().slice(0, 100)
  ```
- Use parameterized queries, never string concatenation
  ```typescript
  // Good
  db.query("SELECT * FROM users WHERE id = ?", [userId])

  // Bad
  db.query(`SELECT * FROM users WHERE id = ${userId}`)
  ```
- Principle of least privilege in flake dev shells
  ```nix
  devShells.default = pkgs.mkShell {
    # Only include necessary packages
    packages = [ pkgs.nodejs pkgs.bun ];
  };
  ```

### Nix Runtime and Package Management

**Nix availability:**
- **Always check if Nix is installed/running before Nix operations**
- Warn user and halt unless explicitly stated otherwise
  ```bash
  if ! command -v nix &> /dev/null; then
      echo "Error: Nix not installed or not in PATH" >&2
      echo "Install: https://nixos.org/download" >&2
      exit 1
  fi
  ```

**Package scope management:**
- **Non-interactive nix-shell or nix run for out-of-scope packages**
  ```bash
  # Don't: Enter shell interactively
  nix-shell -p jq

  # Do: Run command directly
  nix-shell -p jq --run "jq '.key' file.json"
  # OR
  nix run nixpkgs#jq -- '.key' file.json
  ```
- **Add to devShell if used frequently**
  ```nix
  devShells.default = pkgs.mkShell {
    packages = with pkgs; [
      jq  # Used in multiple scripts
      yq  # Used in multiple scripts
    ];
  };
  ```
- **Why:** Entering shells is heavyweight; commands are typically one-shot

**Package conflicts:**
- **Pass conflicting commands through devShell, don't enter it**
  ```bash
  # Package conflicts with system version
  nix develop --command python3 script.py

  # Not recommended: Entering the shell
  nix develop  # Then manually running commands
  ```
- **Why:** Commands are one-shot in such environments; entering wastes time

**Example workflow:**
```bash
# Check Nix availability
command -v nix &> /dev/null || { echo "Nix required"; exit 1; }

# One-shot command with package
nix-shell -p pandoc --run "pandoc input.md -o output.pdf"

# If used repeatedly, add to devShell instead
```

### Performance Guidelines

- Measure before optimizing (use `hyperfine` for benchmarks)
- Cache expensive computations
  ```nix
  # Nix automatically caches, but be mindful of IFD
  let
    heavyComputation = import ./expensive.nix { inherit pkgs; };
  in
  # heavyComputation result is cached
  ```
- Avoid N+1 patterns
  ```typescript
  // Bad: N queries
  for (const user of users) {
      const posts = await db.getPosts(user.id)
  }

  // Good: 1 query
  const posts = await db.getPostsByUserIds(users.map(u => u.id))
  ```
- Consider algorithmic complexity
  ```typescript
  // O(n²) - problematic for large n
  for (const item of items) {
      for (const other of items) { ... }
  }

  // O(n) with Set lookup
  const itemSet = new Set(items)
  for (const item of items) {
      if (itemSet.has(target)) { ... }
  }
  ```

## 3. Naming

**Rationale:** Consistent naming conventions make file systems predictable and scriptable.

| Context | Convention | Example | Why |
|---------|------------|---------|-----|
| Directory | snake_case | `user_profiles/` | Readable, no escaping needed |
| File | kebab-case | `auth-middleware.js` | Web-friendly, clear word boundaries |

**Exceptions:**
- **Single-word files:** `flake.nix`, `default.nix`, `shell.nix` (no case conversion needed)
- **Ecosystem-mandated:** `package.json`, `go.mod`, `Cargo.toml`, `flake.lock`
- **Generated artifacts:** `build.json`, `output.log` (often tool-determined)

**Note:** Follow language-specific conventions for code identifiers (camelCase in JS, snake_case in Python, etc.).

## 4. Structure

**Rationale:** Shallow hierarchies reduce navigation time and path complexity. Deep nesting obscures relationships and makes refactoring harder. Modular design aids self-documentation and conflict tracing.

**Rules:**
- **Max depth:** 6 levels from repository root
  - Counting: Start from repo root (where `.git` lives)
  - Monorepo note: Count from app/package root instead (e.g., `apps/myapp/` is depth 0)
- **Dir names:** Simple, descriptive, single-purpose (e.g., `auth/`, `models/` — not `miscellaneous/`, `stuff/`)
- **Configurable files:** Group flat rather than deep (user-facing settings should be easy to find)

**Modular design:**
- **Prefer modules over large files** unless:
  - Limitation prevents splitting (e.g., single-file deployment requirement)
  - Portable script needs self-containment
  - User explicitly requests monolithic structure
- **Benefits:**
  - Self-documenting through file organization
  - Easy to examine individual components
  - Conflict tracing shows which module changed
  - Enables selective imports/overrides
- **Tree should be intuitive:** Newcomers should understand structure from directory names alone

**Repository organization:**
- **Monorepo:** Each app/package maintains its own 6-level budget
  ```
  repo/
  ├── apps/
  │   └── api/          # Depth 0 for this app
  │       └── src/      # Depth 1
  ├── packages/
  │   └── shared/       # Depth 0 for this package
  ```
- **Polyrepo:** Single app per repo, depth counted from root

**Anti-pattern:**
```
configuration/
  home/
    home_modules/
      some_category/
        subdir/
          file.nix  # Too deep, unclear context
```

**Preferred:**
```
configuration/
  home/
    some-category.nix  # Flat, obvious

# OR if multiple related files:
configuration/
  home/
    auth/
      login.nix       # Clear, modular
      tokens.nix
      sessions.nix
```

**Lazy design principle:**
- Reduce manual maintenance needs where critical
- Common configs should be easy to reach and remember
- Tree structure should encourage exploration
- Optimize for newcomer comprehension

## 5. Comments

**Rationale:** Comments should explain *why*, not *what*. Code should be self-documenting for the "what". Redundant comments increase maintenance burden.

**Default stance:** Discourage comments unless explicitly requested. Code structure and naming should convey intent.

**Keep only when necessary:**
- Non-obvious context (explains *why* this approach was chosen)
  - `// Uses bubble sort: dataset is nearly sorted, O(n) in practice`
- Rationale for decisions
  - `// Timeout set to 30s due to legacy API latency`
- Warnings
  - `// CRITICAL: Must run before database migrations`
- External references
  - `// Implementation based on RFC 7519 Section 4.1.4`

**Always remove:**
- Restatements of code (describes *what* is happening)
  - Bad: `// Increment counter` above `counter++`
  - Bad: `// Detect actual remote origin` above `git remote get-url origin`
- Header duplicates
  - If header says "Purpose: Validates tokens", don't repeat in comment below
- Decoration
  - `// ========== SECTION START ==========`
- Obvious statements
  - `// Create variable` above `let x = 5`

**Example transformation:**
```javascript
// Before
// This function adds two numbers together
function add(a, b) {
  return a + b;  // Return the sum
}

// After
function add(a, b) {
  return a + b;
}
```

**When user requests comments:** Provide them, but note the maintenance cost.

**Note on examples:** Rule 15 examples include inline comments for *illustration purposes* to explain patterns to readers. In actual code, these would be removed unless they explain *why* (rationale) rather than *what* (description).

## 6. Navigation

**Rationale:** Direct search is faster than IDE indexing in large/unfamiliar codebases. grep works everywhere.

**Use `grep` for:**
- **Finding imports:**
  ```bash
  grep -r "import.*auth" src/
  # Shows where auth module is used
  ```
- **Finding definitions:**
  ```bash
  grep -r "function authenticate" src/
  grep -r "def process_order" services/
  ```
- **Cross-referencing:**
  ```bash
  grep -r "DATABASE_URL" .
  # Finds all references to config variable
  ```

**Pro tips:**
- Add `-n` for line numbers: `grep -rn "pattern" path/`
- Add `-i` for case-insensitive: `grep -ri "error" logs/`
- Use `-l` to list files only: `grep -rl "TODO" src/`

## 7. File Hygiene

**Rationale:** Orphaned files create confusion and technical debt. Unreferenced modules suggest incomplete refactoring.

**Rules:**
- **Every module must be imported/referenced somewhere**
  - Exception: Entry points (main.js, index.html)
- **Wire in on create:** Add import immediately after creating file (prevents orphans)
- **Remove refs before delete:** Find all imports/references first
  ```bash
  grep -r "filename" .  # Check before deleting
  ```
- **Never commit:**
  - Artifacts: `*.o`, `*.pyc`, `dist/`, `build/`
  - Build outputs: `node_modules/`, `target/`, `.next/`
  - Editor state: `.vscode/`, `.idea/`, `*.swp`

**Verification workflow:**
```bash
# Before deleting auth-helper.js:
grep -r "auth-helper" src/
# If found: remove imports, update tests
# If not found: safe to delete
```

## 8. User-Configurable Files

**Rationale:** Separating config from logic allows customization without touching core code. Reduces merge conflicts and makes upgrades easier.

**Pattern:**
```
project/
  core/           # Stable, rarely changed
    engine.js
    validator.js
  config/         # User-customizable
    packages.yml
    services.yml
    preferences.json
```

**Benefits:**
- Users edit `config/` without understanding `core/`
- Base config stays stable across versions
- Clear separation of "what to run" vs "how it runs"

**Example:**
```yaml
# config/packages.yml
packages:
  - git
  - vim
  - nodejs

# vs editing core/setup.sh directly
```

## 9. DRY Refactoring

**Rationale:** Don't Repeat Yourself. Duplication creates maintenance burden and inconsistency risks.

**Process:**
1. **Extract repeated values** to shared bindings
   ```javascript
   // Before
   api.call({ timeout: 5000 });
   fetch.get({ timeout: 5000 });

   // After
   const API_TIMEOUT = 5000;
   api.call({ timeout: API_TIMEOUT });
   fetch.get({ timeout: API_TIMEOUT });
   ```

2. **Replace inline duplicates** with references
   ```python
   # Before: same validation logic in 3 places

   # After
   def validate_email(email):
       return re.match(r'^[^@]+@[^@]+\.[^@]+$', email)
   ```

3. **Flatten single-key nested structures**
   ```javascript
   // Before
   config: {
     database: {
       url: "..."
     }
   }

   // After (if database only has url)
   config: {
     databaseUrl: "..."
   }
   ```

4. **Consolidate single-attribute blocks**
   ```css
   /* Before */
   .btn { color: blue; }
   .btn { padding: 10px; }

   /* After */
   .btn {
     color: blue;
     padding: 10px;
   }
   ```

5. **Self-documenting variable names**
   ```javascript
   // Before
   const x = 86400000;

   // After
   const MILLISECONDS_PER_DAY = 86400000;
   ```

## 10. Commit Messages

**Rationale:** Structured messages enable automation (changelog generation, filtering), and provide searchable history.

**Format:**
```
<type>(scope): <verb> <summary>
```

**Types:** `feat` `fix` `refactor` `docs` `style` `test` `chore` `perf` `revert`

**Rules:**
- **Scope:** Basename, lowercase, max 3 words
  - Good: `auth`, `user-model`, `api-client`
  - Bad: `src/services/auth`, `AUTHENTICATION`
- **Summary:** Imperative, lowercase start, no trailing punctuation, max 72 chars
  - Good: `add token refresh logic`
  - Bad: `Added token refresh logic.` (past tense, punctuation)
  - **Line length note:** 72 for commit messages (git log readability), 100 for code (Rule 2)
- **Single-line only:** No body unless required by team
- **Mark untested:** Append `[untested]` if validation skipped (e.g., flake check)
  - `feat(system): add docker support [untested]`
- **Mark skip-check:** Append `[skip-check]` if intentionally bypassing validation
  - `fix(config): workaround for known nixpkgs issue [skip-check]`

**Examples:**
```
feat(auth): add JWT refresh endpoint
fix(api-client): handle network timeouts gracefully
refactor(user-model): extract validation to separate module
docs(readme): clarify installation steps
test(auth): add edge cases for token expiry
feat(system): enable wayland compositor [untested]
chore(flake): update nixpkgs input [skip-check]
```

**Regex validation:**
```regex
^(feat|fix|docs|style|refactor|test|chore|perf|revert)\([^)]+\): [a-z].+[^.]$
```

**With flags:**
```regex
^(feat|fix|docs|style|refactor|test|chore|perf|revert)\([^)]+\): [a-z].+[^. ]( \[(untested|skip-check)\])?$
```

**Note:** Scope pattern `[^)]+` intentionally permits hyphens, numbers, etc. for flexibility (e.g., `api-v2`, `user-model-3`). Enforce naming convention in review if needed.

## 11. Commit Workflow

**Rationale:** Frequent commits create checkpoints. Consolidation keeps history meaningful. Open-loop prevents blocking on feedback.

### Git Staging for Nix Projects

**Critical:** Nix flakes read from git tree. Always stage files before running flake commands.

```bash
# Stage new files (required for flake commands to see them)
git add --intent-to-add .   # Minimal staging
# OR
git add .                   # Full staging

# Now flake commands work
nix flake check
nix build
```

**Why:** Unstaged files don't exist in git tree, causing "file not found" errors in flake operations.

**Git staging pattern (portable):**
```fish
if test -d .git
    git add --intent-to-add . 2>/dev/null; or true
end
```

### Branch Strategy

**Default:** Stay in current branch unless explicitly instructed otherwise.

**Why:** Branch histories aren't always synced downstream. Switching branches without instruction can cause conflicts.

**Example branch hierarchy** (project-specific, adapt as needed):
- `main` / `master`: Stable, production-ready
- `dev`: New features and changes
- `dev-experimental`: Experimental changes, may be unstable
- `dev-very-experimental`: Large, breaking changes

**Note:** This hierarchy is illustrative. Actual branch strategy depends on project workflow.

**When to switch branches:**
- User explicitly requests: "work on dev branch"
- New feature/change requires dev branch
- User specifies experimental nature of work

**When to stay put:**
- No branch specified
- Fixing/editing existing code
- Small changes to current context
- Uncertain which branch is appropriate

**Example:**
```bash
# User says "add new package"
# Response: "Should I work on dev branch or stay in current?"

# User says "experiment with wayland config"
# Response: Creates/switches to dev-experimental

# User says "fix typo in readme"
# Response: Stays in current branch
```

### Merge/Integration Strategy

**Default:** Project-specific. Common patterns:

**Merge commit** (preserves full history):
```bash
git checkout main
git merge --no-ff feature-branch
```
- **Pros:** Full history visible, easy to revert entire feature
- **Cons:** Noisy history with many merge commits

**Rebase** (linear history):
```bash
git checkout feature-branch
git rebase main
git checkout main
git merge --ff-only feature-branch
```
- **Pros:** Clean linear history
- **Cons:** Rewrites commits (never on shared branches)

**Squash merge** (single commit per feature):
```bash
git checkout main
git merge --squash feature-branch
git commit -m "feat(scope): implement feature"
```
- **Pros:** One commit per feature, clean main history
- **Cons:** Loses intermediate commits

**Guidelines:**
- **main/production:** Prefer squash or merge commits
- **dev branches:** Rebase acceptable before merge
- **Experimental branches:** Rebase freely (not synced downstream)
- **Shared branches:** Never rebase
- **When in doubt:** Ask user for merge strategy preference

### Commit Cadence

**Default mode: Commit iteratively (open-loop)**
```bash
# Iteration 1
git add --intent-to-add config.nix
git add config.nix
git commit -m "feat(system): add docker support [untested]"

# Iteration 2 (continue working)
git add packages.nix
git commit -m "feat(packages): add docker-compose [untested]"

# Iteration 3 (more changes)
git add services.nix
git commit -m "feat(services): configure docker daemon [untested]"
```

**After validation: Squash commits**
```bash
# Validate the entire changeset
nix flake check

# If passing, squash related commits
git rebase -i HEAD~3

# In editor, mark commits to squash:
# pick abc123 feat(system): add docker support [untested]
# squash def456 feat(packages): add docker-compose [untested]
# squash ghi789 feat(services): configure docker daemon [untested]

# Final commit message (remove [untested] flags):
# feat(system): add docker support with compose and daemon
```

**Safe rebase for better commits:**
- **Only on dev-experimental or dev-very-experimental branches**
- Never rebase main, dev, or shared branches
- Use for cleaning up commit history before merging
  ```bash
  # Check current branch
  git branch --show-current

  # Only if on dev-experimental or dev-very-experimental
  git rebase -i HEAD~5
  ```
- **Why:** Experimental branches aren't synced downstream; safe to rewrite

**When to squash:**
- Changes validated and work together
- Before pushing to main/shared branch
- Multiple commits implementing single feature
- Cleaning up iteration history

**When NOT to squash:**
- Each commit is logically independent
- Different features/fixes that happen to be nearby
- Commits already pushed to shared branch (rewriting public history)
- On main or dev branch (unless explicitly permitted)

**Open-loop benefit:** Commit frequently without waiting for validation. Validate once, squash if passing. Maintains momentum while creating undo points.

**Example workflow:**
```bash
# Fast iteration (3 commits in 10 minutes)
git add --intent-to-add .
vim config.nix && git add config.nix && git commit -m "feat(config): add X [untested]"
vim packages.nix && git add packages.nix && git commit -m "feat(config): add Y [untested]"
vim services.nix && git add services.nix && git commit -m "feat(config): add Z [untested]"

# Single validation when done iterating
nix flake check

# Squash and clean up (only on experimental branches)
git rebase -i HEAD~3
# Result: One clean commit with all changes
```

## 12. Documentation

**Rationale:** Documentation has high maintenance burden. Code and project structure should self-document when possible.

**Default stance:** Avoid markdown documentation unless explicitly requested.
- **Why:** Markdown docs go stale quickly
- Project tree should be intuitive enough to explore
- Code structure and naming convey intent
- Encourages hands-on exploration over passive reading

**When documentation is needed:**
- Duplicate facts over cross-refs
  - Bad: "See section 3.2 for details"
  - Good: Restate the essential detail inline
- State current facts, no time markers
  - Bad: "As of 2024, the API uses..."
  - Good: "The API uses..."
- No priority markers
  - Bad: "TODO (HIGH PRIORITY): Fix bug"
  - Good: "Fix: API returns 500 on empty payload"
- Verified claims only
  - If unsure, say "may" or "typically" rather than stating as fact

**Code blocks when used:**
````markdown
```javascript
const result = doThing();
```
````

**Trees (max 4 levels):**
```
project/
├── src/
│   ├── auth/
│   │   ├── login.js
│   │   └── logout.js
│   └── api/
└── tests/
```

**Self-documenting structure example:**
```
configuration/
├── system/           # Clear: system-level config
│   ├── boot.nix
│   ├── network.nix
│   └── users.nix
├── home/            # Clear: user-level config
│   ├── shell.nix
│   └── editor.nix
└── secrets/         # Clear: sensitive data
    └── api-keys.age
```

**Lazy principle:** Tree exploration > README maintenance. Newcomers learn by examining structure.

## 13. Validation

**Rationale:** Automated checks catch errors before they reach production. Committing broken code wastes reviewer time.

**Rule:** Run project checks before commit, with exceptions for resource-intensive operations.

**Typical checks:**
```bash
npm test              # JS/TS
pytest                # Python
cargo test            # Rust
go test ./...         # Go
nix flake check       # Nix (see policy below)
```

### Flake Check Policy

**Default:** Ask before running `nix flake check` unless explicitly permitted.

**Rationale:** `nix flake check` is resource-intensive and CI is typically configured to run it automatically.

**Workflow:**
```fish
# Interactive: Ask first
"Run nix flake check? (resource-intensive, CI already configured)"
# If yes:
nix flake check --accept-flake-config
# Add --impure only if the flake requires it (e.g., impure inputs)
# Using --impure by default undermines reproducibility

# Skip if:
# - CI handles validation
# - Local resources limited
# - Iterating rapidly
```

**When skipping validation:**
- Mark commit as untested: `feat(config): add new package [untested]`
- CI will catch issues on push
- Avoids blocking local development

**Never commit failing check** unless:
- Flagged with `[skip-check]` in commit message
- Documented reason (e.g., known infra issue, WIP branch)

**Example workflow:**
```bash
# Make changes
vim configuration.nix

# Local validation (fast checks)
statix fix .
deadnix -e .
treefmt

# Ask about flake check
# If permitted or critical change:
nix flake check --impure --accept-flake-config

# Commit with appropriate flag
git add configuration.nix
git commit -m "feat(system): add docker support"  # If validated
# OR
git commit -m "feat(system): add docker support [untested]"  # If skipped
```

**If checks fail:**
- Fix immediately, or
- Stash changes and return later, or
- Document with `[skip-check]` or `[untested]` and explain why

## 14. CI/CD Configuration

**Rationale:** Automated pipelines catch errors, enforce standards, and enable confident deployment. Well-structured CI reduces manual overhead.

### Workflow Organization

**File location:** `.github/workflows/` (GitHub Actions)

**Naming convention:**
- Use kebab-case: `flake-check.yml`, `sync-dev-main.yml`
- Descriptive names: what the workflow does
- Avoid generic names: `ci.yml`, `test.yml` (too vague in multi-workflow projects)

**Header format** (portable workflows):
```yaml
# Workflow Name (Portable)
#
# Purpose: One-line description of what this workflow does
# Triggers: When this workflow runs
# Dependencies: External actions used
#
# This workflow:
# - Bullet point of key action
# - Bullet point of key action
```

### Trigger Patterns

**Nix flake validation:**
```yaml
on:
  push:
    paths:
      - '**.nix'
      - '**.lock'
  pull_request:
    paths:
      - '**.nix'
      - '**.lock'
  workflow_dispatch:  # Manual trigger
```

**Branch-specific:**
```yaml
on:
  push:
    branches: [main, dev]
  pull_request:
    branches: [main, dev]
```

**Manual-only workflows:**
```yaml
on:
  workflow_dispatch:
    inputs:
      board:
        description: 'Target board'
        required: true
        type: choice
        options: [dedede, octopus, zork]
```

### CI Principles

**Fast feedback:**
- Run fast checks first (linting, formatting)
- Expensive operations last (builds, tests)
- Fail fast on critical errors

**Caching strategy:**
```yaml
- name: Setup Cachix
  uses: cachix/cachix-action@v14
  with:
    name: your-cache-name
    authToken: '${{ secrets.CACHIX_AUTH_TOKEN }}'
    skipPush: true  # Manual control of what gets cached
```

**Retry logic for flaky operations:**
```bash
success=false
for i in {1..3}; do
  if command_that_might_fail; then
    success=true
    break
  fi
  echo "Attempt $i/3 failed. Retrying in 10s..."
  sleep 10
done
[ "$success" = "false" ] && exit 1
```

**Resource management:**
```yaml
- name: Maximize build space
  run: |
    sudo rm -rf /usr/share/dotnet /usr/local/lib/android
    sudo docker image prune --all --force
```

### Formatting Automation

**Auto-format on manual dispatch:**
```yaml
- name: Auto-format Nix files
  run: nix fmt .

- name: Auto-commit & push (manual dispatch only)
  if: github.event_name == 'workflow_dispatch'
  run: |
    if ! git diff --quiet; then
      git add '*.nix'
      git commit -m "style: auto-format nix files (CI)"
      git push
    fi

- name: Verify formatting (sanity check)
  run: nix fmt -- --fail-on-change .
```

**Why manual-only:** Prevents commit loops, explicit user action required

### Branch Synchronization

**Merge strategy in CI:**
```yaml
- name: Attempt merge
  run: |
    # Prefer source branch changes
    git merge "origin/${FROM_BRANCH}" --strategy-option=theirs --no-edit

    # Create backup before conflict resolution
    if git ls-files -u | grep -q .; then
      BACKUP_TAG="premerge-${TO_BRANCH}-$(date +'%Y%m%d-%H%M')"
      git tag -a "$BACKUP_TAG" -m "Backup before merge"
      git push origin "$BACKUP_TAG"
    fi
```

**Fallback to PR on conflict:**
```yaml
- name: Create PR if conflict
  if: env.MERGE_CONFLICT == '1'
  uses: peter-evans/create-pull-request@v7
  with:
    title: "chore: sync dev → main (conflicts detected)"
    body: Manual resolution required. Backup tag created.
```

### Build Matrices

**Multi-board builds:**
```yaml
strategy:
  fail-fast: false
  matrix:
    board: >-
      ${{
        github.event.inputs.board == 'all'
        && fromJSON('["dedede", "octopus", "zork"]')
        || fromJSON(format('["{0}"]', github.event.inputs.board))
      }}
```

**Why fail-fast: false:** Allow all boards to attempt build even if one fails

### Secrets Management

**Required secrets:**
- `CACHIX_AUTH_TOKEN`: For binary cache push
- `GITHUB_TOKEN`: Automatically provided, for PR creation

**Usage:**
```yaml
env:
  CACHIX_AUTH_TOKEN: ${{ secrets.CACHIX_AUTH_TOKEN }}
```

**Never hardcode:** API keys, tokens, passwords in workflow files

### Artifact Handling

**Upload patterns:**
```yaml
- name: Upload Artifact
  uses: actions/upload-artifact@v4
  with:
    name: ${{ matrix.board }}-shimboot-${{ inputs.rootfs }}
    path: artifacts/${{ matrix.board }}/*
```

**Download for release:**
```yaml
- name: Download Artifacts
  uses: actions/download-artifact@v4
  with:
    path: release-artifacts
    merge-multiple: true
```

### Release Automation

**Conditional release job:**
```yaml
create-release:
  needs: build
  if: ${{ github.event.inputs.create_release == 'true' }}
  runs-on: ubuntu-latest
```

**Dynamic release body:**
```yaml
- name: Generate Release Metadata
  id: metadata
  run: |
    TIMESTAMP=$(date -u '+%Y.%m.%d.%H%M-UTC')
    echo "timestamp=${TIMESTAMP}" >> "$GITHUB_OUTPUT"

    # Heredoc for multi-line output
    EOF=$(dd if=/dev/urandom bs=15 count=1 status=none | base64)
    echo "body<<$EOF" >> "$GITHUB_OUTPUT"
    echo "## Release ${TIMESTAMP}" >> "$GITHUB_OUTPUT"
    # ... more content
    echo "$EOF" >> "$GITHUB_OUTPUT"
```

### Permissions

**Minimal required permissions:**
```yaml
permissions:
  contents: write      # For pushing commits, creating releases
  pull-requests: write # For creating PRs
```

**Default:** Use `contents: read` unless write needed

### What CI Should Validate

**Nix projects:**
- `nix fmt` (formatting)
- `nix flake check` (integrity)
- Build critical derivations
- Push to binary cache

**General projects:**
- Linting (language-specific)
- Unit tests
- Integration tests (if fast enough)
- Security scans (dependabot, etc.)

**What CI should NOT do:**
- Manual steps requiring human judgment
- Operations with side effects on prod
- Long-running tests blocking PRs (move to nightly)

## 15. Principles

**KISS:** Keep It Simple, Stupid
- Prefer obvious over clever
- Future you will thank present you

**DRY:** Don't Repeat Yourself
- Single source of truth
- Changes propagate automatically

**Maintainable over clever:**
- Code is read 10x more than written
- Optimize for the next person (often you)

**Lazy optimization:**
- Reduce manual maintenance needs where critical
- Automate repetitive tasks
- Make common operations memorable

**Examples:**
```javascript
// Clever (bad)
const f = (x) => x.split('').reverse().join('');

// Maintainable (good)
const reverseString = (str) => {
  return str.split('').reverse().join('');
};
```

## 16. Tone and Formatting

**Rationale:** Clear, professional communication without unnecessary decoration.

**Rules:**
- **No emoticons** unless explicitly requested
  - Bad: `# 🚀 Deploy script`
  - Good: `# Deploy script`
- **Abbreviate common terms** (unless stated otherwise):
  - configuration → config (context-dependent)
  - repository → repo
  - temporary → temp
  - initialize → init
- **Professional tone:** Technical, direct, unambiguous
- **Avoid redundancy:** Each word should add value

## 17. Example Patterns

See [DEV-EXAMPLES.md](./DEV-EXAMPLES.md) for concrete reference examples from real projects (NixOS/Home Manager/Hyprland/Fish context). Optional reading.

## 18. New Rule Files

**Rationale:** Rule proliferation creates cognitive burden. New files must earn their existence.

**Create only when:**
- Content doesn't fit existing file
- Serves distinct, standalone purpose
- Substantial enough to stand alone (not a single rule)

**Structure:** Title → Purpose → Content → Validation

**Format:**
- Filename: `kebab-case.md`
- Hierarchy: H1 → H2 → H3 (no H4+)
- No decoration (borders, emoji, ASCII art)

**Checklist before creating:**
- [ ] Can this be added to existing file?
- [ ] Does it cover a distinct concern?
- [ ] Is it >100 words of unique content?
- [ ] Will it be referenced >3 times?

**Example:** Don't create `variable-naming-rules.md` when it fits in existing `code-style.md`.

## 19. Changelog Policy

**Rationale:** Changelogs provide human-readable summaries of what changed per merge. Generating them from git history before merging ensures accuracy and creates an audit trail. Archiving keeps the root clean.

**Policy:** Generate a changelog before every merge to main. Root contains only the latest; previous changelogs live in `changelog-archive/`.

### Structure

```
repo/
├── CHANGELOG-<short-hash>.md        # Latest (current merge)
└── changelog-archive/
    ├── CHANGELOG-a1b2c3d.md          # Previous merges
    ├── CHANGELOG-e4f5g6h.md
    └── ...
```

**Filename format:** `CHANGELOG-<7-char-short-hash>.md` using the merge commit hash.

### Generating the Changelog

**Diff commits between main and current branch:**

```bash
git log main..HEAD --oneline --no-merges
```

**Full generation script (bash):**

```bash
#!/usr/bin/env bash
set -Eeuo pipefail

TARGET_BRANCH="main"
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "detached")
ARCHIVE_DIR="changelog-archive"

if [[ "$CURRENT_BRANCH" == "detached" ]]; then
    echo "Error: cannot generate changelog in detached HEAD state" >&2
    exit 1
fi

if [[ "$CURRENT_BRANCH" == "$TARGET_BRANCH" ]]; then
    echo "Error: already on $TARGET_BRANCH, switch to feature branch" >&2
    exit 1
fi

# Collect commits between target and current branch
COMMITS=$(git log "$TARGET_BRANCH..HEAD" --oneline --no-merges 2>/dev/null || true)

if [[ -z "$COMMITS" ]]; then
    echo "No new commits relative to $TARGET_BRANCH" >&2
    exit 1
fi

# Detect merge type based on branch relationship
MERGE_TYPE="Merge commit"
if git merge-base --is-ancestor "$TARGET_BRANCH" HEAD 2>/dev/null; then
    MERGE_TYPE="Fast-forward"
fi

# Placeholder hash (replaced after merge with actual commit hash)
PLACEHOLDER="pending"
CHANGELOG="CHANGELOG-${PLACEHOLDER}.md"

# Archive existing root changelogs
mkdir -p "$ARCHIVE_DIR"
for old in CHANGELOG-*.md; do
    [[ -f "$old" ]] && mv "$old" "$ARCHIVE_DIR/"
done

# Generate changelog
cat > "$CHANGELOG" <<EOF
# Changelog — ${CURRENT_BRANCH} → ${TARGET_BRANCH}

**Date:** $(date -u +"%Y-%m-%d")
**Branch:** ${CURRENT_BRANCH}
**Merge type:** ${MERGE_TYPE} (linear history)
**HEAD:** \`pending\` (rename after merge)

## Commits

\$(format_commits)

## Files changed

\`\`\`
\$(git diff --stat "$TARGET_BRANCH...HEAD" 2>/dev/null | head -100)
\`\`\`
EOF

echo "Generated: $CHANGELOG"
echo "After merge, rename with: mv $CHANGELOG CHANGELOG-\$(git rev-parse --short HEAD).md"
```

### Post-Merge Rename

After the merge commit exists, rename the file with the actual hash:

```bash
# Using the script
./generate-changelog.sh --rename

# Or manually
MERGE_HASH=$(git rev-parse --short HEAD)
mv CHANGELOG-pending.md "CHANGELOG-${MERGE_HASH}.md"
git add "CHANGELOG-${MERGE_HASH}.md" changelog-archive/
git commit --amend --no-edit
```

### Changelog Format

```markdown
# Changelog — feature-branch → main

**Date:** 2026-02-13
**Branch:** dev
**Merge type:** Fast-forward (linear history)
**HEAD:** `a1b2c3d`

## Commits

- feat(auth): add JWT refresh endpoint ([`f1a2b3c`](https://github.com/org/repo/commit/f1a2b3c))
- fix(api): handle network timeouts ([`d4e5f6a`](https://github.com/org/repo/commit/d4e5f6a))
- test(auth): add token expiry edge cases ([`b7c8d9e`](https://github.com/org/repo/commit/b7c8d9e))

## Files changed

```
 src/auth/tokens.ts    | 42 +++++++++++++++---
 src/api/client.ts     | 18 +++++---
 tests/auth.test.ts    | 35 +++++++++++++++
 3 files changed, 82 insertions(+), 13 deletions(-)
```
```

**Merge type field:**
- **Fast-forward:** Current branch is descendant of target (linear history)
- **Merge commit:** Current branch has diverged (requires merge commit)

### Rules

- **One root changelog:** Only the latest `CHANGELOG-<hash>.md` lives in root
- **Archive on generation:** Move any existing root changelog to `changelog-archive/` before writing a new one
- **Generate before merge:** Changelog reflects the branch diff, not post-merge guesswork
- **Rename after merge:** Replace `pending` placeholder with actual merge commit short hash
- **No empty changelogs:** Skip generation if no commits differ from main
- **Commit the changelog:** Include it in the merge commit itself (or amend)
- **`changelog-archive/` is append-only:** Never delete archived changelogs unless explicitly requested

### Commit Message

```
docs(changelog): add changelog for <branch> merge (<short-hash>)
```

### Gitignore Consideration

Do **not** gitignore changelogs. They are project history.

```gitignore
# Do NOT add:
# CHANGELOG-*.md
# changelog-archive/
```

---

[↑ Back to Top](#development) | [Table of Contents](#table-of-contents)
