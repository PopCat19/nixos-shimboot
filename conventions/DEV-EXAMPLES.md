# Example Patterns

**Rationale:** Concrete examples demonstrate conventions in practice.

**Note:** These examples illustrate patterns from DEVELOPMENT.md rules. Adapt to your project's stack and requirements. Comments explain *why* where appropriate; follow Rule 5 for actual code.

## File Headers (Rule 1)

**Module header:**
```python
# auth_service.py
#
# Purpose: Manages user authentication tokens
#
# This module:
# - Validates JWT signatures
# - Refreshes expired tokens
# - Handles token revocation
```

**Portable script header:**
```bash
#!/usr/bin/env bash
#
# deploy.sh
#
# Purpose: Deploy application to staging environment
# Dependencies: docker, kubectl, jq
# Related: config/deploy.env, scripts/build.sh
#
# Usage:
#   ./deploy.sh [OPTIONS]
#
# Options:
#   --env ENVIRONMENT    Target environment (staging|production)
#   --dry-run           Show actions without executing
#
# Examples:
#   ./deploy.sh --env staging
#   ./deploy.sh --env production --dry-run
```

## Code Style (Rule 2)

**Flatten nesting:**
```javascript
// Before
function process(data) {
  if (data) {
    if (data.valid) {
      if (data.ready) {
        return transform(data);
      }
    }
  }
}

// After
function process(data) {
  if (!data) return null;
  if (!data.valid) return null;
  if (!data.ready) return null;
  return transform(data);
}
```

**Extract repeated values:**
```typescript
// Before
api.call({ timeout: 5000 });
fetch.get({ timeout: 5000 });
db.query({ timeout: 5000 });

// After
const API_TIMEOUT_MS = 5000;
api.call({ timeout: API_TIMEOUT_MS });
fetch.get({ timeout: API_TIMEOUT_MS });
db.query({ timeout: API_TIMEOUT_MS });
```

**Early returns for error checking:**
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

## CLI Presentation (Rule 2 / Rule 5)

**Source a shared lib rather than inline ANSI:**
```bash
# Bad: inline color strings scattered across scripts
printf '\033[1;32m  ✓ %s\033[0m\n' "$1"

# Good: source once, use named functions
source "$(dirname "$0")/../tools/libcli.sh"
log_success "Rootfs mounted"
```

**Log level conventions:**
```bash
log_step  "2/8" "Format partitions"   # [2/8] Format partitions   (bold blue)
log_info  "Loop device: /dev/loop0"   #   →   (green)
log_warn  "Cache miss, building..."   #   !   (yellow)
log_error "Mount failed: EBUSY"       #   ✗   (red, stderr)
log_success "Image ready"             #   ✓   (green)
log_cmd   "parted --script img ..."   #   $   (dim)
log_sep                               # ────  (dim rule, terminal width)
```

**Step counter — declare total upfront:**
```bash
cli_steps_init 8
CURRENT_STEP="$(cli_step_next)"   # → "1/8"
log_step "$CURRENT_STEP" "Build Nix outputs"

CURRENT_STEP="$(cli_step_next)"   # → "2/8"
log_step "$CURRENT_STEP" "Harvest drivers"
```

**Banner for script entry points:**
```bash
cli_banner "Deploy Tool" "env: staging · version: 1.4.2"
# Output:
# ────────────────────────────────────────────────────────────────────────────
#   Deploy Tool
#   env: staging · version: 1.4.2
# ────────────────────────────────────────────────────────────────────────────
```

**safe_exec respects DRY_RUN automatically:**
```bash
# Bad: manual dry-run guards repeated everywhere
if [ "$DRY_RUN" -eq 1 ]; then
    echo "[dry-run] sudo parted ..."
else
    sudo parted --script "$IMAGE" mklabel gpt
fi

# Good: single wrapper
safe_exec sudo parted --script "$IMAGE" mklabel gpt
# dry-run:  prints  →  $ sudo parted --script ...  (no-op)
# live:     prints then executes
```

**Retry transient failures:**
```bash
# Bad: silent retry with manual loop
for i in 1 2 3; do cmd && break; sleep 5; done

# Good
cli_retry 3 5 curl -fsSL "$URL" -o "$DEST"
# Output:
#   → Attempt 1/3: curl ...
#   ! Failed (exit 22), retrying in 5s...
#   → Attempt 2/3: curl ...
#   ✓ (success)
```

**Prompts degrade gracefully in non-tty:**
```bash
# cli_prompt_yn returns 1 (no) silently when stdin is not a tty
# Safe to call unconditionally — no hang in CI

cli_prompt_yn "Enable LUKS2 encryption?" "n" && LUKS_ENABLED=1

cli_prompt_choice "Select flavor:" "1" "full" "minimal" "custom"
log_info "Selected: ${CLI_CHOICE}"
```

**CI color suppression is automatic:**
```bash
# No guard needed — _cli_use_color() checks:
#   isatty, $NO_COLOR, $CI, $GITHUB_ACTIONS
# Plain text emitted automatically in CI pipelines
```

**Fish — same API surface:**
```fish
source (dirname (status filename))/../tools/libcli.fish

cli_banner "NixOS Rebuild" "flake: $NIXOS_CONFIG_DIR"
cli_steps_init 3

log_step (cli_step_next) "Validate environment"
cli_prompt_yn "Disable sandbox?" n
and set -a nix_args --option sandbox false

safe_exec sudo nixos-rebuild switch --flake .
```

**Contextual error blocks pair with log_error:**
```bash
handle_error() {
    local step="$1"
    log_error "Failed at step $step"
    case "$step" in
    "3/8")
        log_error "Troubleshooting:"
        log_error "  1. Check loop devices: losetup -l"
        log_error "  2. Verify free space: df -h"
        ;;
    esac
    exit 1
}
trap 'handle_error "${CURRENT_STEP:-unknown}"' ERR
```

## Naming (Rule 3)

**File naming conventions:**
```
project/
├── user-profiles/        # Directory: snake_case
├── auth-middleware.js    # File: kebab-case
├── flake.nix             # Single-word: no conversion
├── package.json          # Ecosystem-mandated
└── build.log             # Generated artifact
```

## Structure (Rule 4)

**Shallow hierarchy:**
```
# Good: Max 3 levels deep
project/
├── src/
│   ├── auth/
│   │   ├── login.js
│   │   └── tokens.js
│   └── api/
│       └── client.js
└── tests/

# Bad: Too deep
project/
├── src/
│   ├── modules/
│   │   ├── features/
│   │   │   ├── authentication/
│   │   │   │   ├── strategies/
│   │   │   │   │   └── oauth/
│   │   │   │   │       └── providers/
│   │   │   │   │           └── google.js  # 7 levels deep
```

**Modular organization:**
```
# Self-documenting structure
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

## Comments (Rule 5)

**Keep only when necessary:**
```javascript
// Good: Explains why
// Uses bubble sort: dataset is nearly sorted, O(n) in practice
function sortNearlySorted(arr) { ... }

// Good: Warning about critical dependency
// CRITICAL: Must run before database migrations
function cleanup() { ... }

// Bad: Restates what
// Increment counter
counter++;

// Bad: Obvious statement
// Create variable
let x = 5;
```

## File Hygiene (Rule 7)

**Verification before delete:**
```bash
# Before deleting auth-helper.js:
grep -r "auth-helper" src/
# If found: remove imports, update tests
# If not found: safe to delete
```

**Wire in on create:**
```javascript
// After creating new utils/formatter.js
// Immediately add to index.js:
export { format } from './utils/formatter.js'
```

## DRY Refactoring (Rule 9)

**Extract repeated logic:**
```python
# Before: same validation in 3 places
def create_user(email):
    if not re.match(r'^[^@]+@[^@]+\.[^@]+$', email):
        raise ValueError("Invalid email")
    # ...

def update_user(email):
    if not re.match(r'^[^@]+@[^@]+\.[^@]+$', email):
        raise ValueError("Invalid email")
    # ...

# After
def validate_email(email):
    return re.match(r'^[^@]+@[^@]+\.[^@]+$', email)

def create_user(email):
    if not validate_email(email):
        raise ValueError("Invalid email")
    # ...
```

**Self-documenting names:**
```javascript
// Before
const x = 86400000;

// After
const MILLISECONDS_PER_DAY = 86400000;
```

## Commit Messages (Rule 10)

**Format:**
```
<type>(scope): <verb> <summary>

feat(auth): add JWT refresh endpoint
fix(api-client): handle network timeouts gracefully
refactor(user-model): extract validation to separate module
docs(readme): clarify installation steps
test(auth): add edge cases for token expiry
chore(deps): update dependencies
```

**With flags:**
```
feat(system): add docker support [untested]
fix(config): workaround for known issue [skip-check]
```

## Commit Workflow (Rule 11)

**Iterative commits with squash:**
```bash
# Fast iteration
git add --intent-to-add .
vim config.nix && git add config.nix && git commit -m "feat(config): add X [untested]"
vim packages.nix && git add packages.nix && git commit -m "feat(config): add Y [untested]"
vim services.nix && git add services.nix && git commit -m "feat(config): add Z [untested]"

# Validate
nix flake check

# Squash (only on experimental branches)
git rebase -i HEAD~3
# Result: One clean commit
```

## Documentation (Rule 12)

**Self-documenting structure:**
```
# Good: Structure conveys purpose
src/
├── auth/           # Authentication logic
│   ├── login.js
│   └── tokens.js
├── api/            # API client
│   └── client.js
└── utils/          # Shared utilities
    └── format.js

# Avoid: Requires documentation to understand
src/
├── module1/
├── module2/
└── stuff/
```

## Validation (Rule 13)

**Pre-commit workflow:**
```bash
# Make changes
vim configuration.nix

# Fast local checks
statix fix .
deadnix -e .
treefmt

# Commit with appropriate flag
git add configuration.nix
git commit -m "feat(system): add docker support"  # If validated
# OR
git commit -m "feat(system): add docker support [untested]"  # If skipped
```

## CI/CD Configuration (Rule 14)

**Workflow header:**
```yaml
# Flake Check (Portable)
#
# Purpose: Validate Nix flake on push/PR
# Triggers: Push/PR to main, manual dispatch
# Dependencies: cachix/cachix-action@v14
#
# This workflow:
# - Checks flake inputs and outputs
# - Runs statix and deadnix linters
# - Pushes to binary cache
```

**Table-driven tests:**
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

## Principles (Rule 15)

**Maintainable over clever:**
```javascript
// Clever (bad)
const f = (x) => x.split('').reverse().join('');

// Maintainable (good)
const reverseString = (str) => {
  return str.split('').reverse().join('');
};
```

## Error Messaging

**Contextual error messages:**
```bash
case "$step" in
"database-connection")
    log_error "Database connection failed. Check:"
    log_error "  1. Database server is running"
    log_error "  2. Connection string is correct"
    log_error "  3. Network connectivity: ping db-host"
    ;;
"file-upload")
    log_error "File upload failed. Possible causes:"
    log_error "  1. Insufficient disk space: df -h"
    log_error "  2. Permission denied: check directory permissions"
    log_error "  3. File too large: check size limits"
    ;;
esac
```

**Why:** Provides actionable troubleshooting steps instead of cryptic errors.

## Build Metadata

**Structured build info:**
```bash
sudo tee "$DEST/.build_info" >/dev/null <<EOF
# Build metadata
BUILD_HOST=$(hostname)
BUILD_USER=$(whoami)
BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)
GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo unknown)
EOF
```

**JSON metadata:**
```bash
sudo tee "$DEST/build.json" >/dev/null <<EOF
{
  "build_date": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "build_host": "$(hostname)",
  "git_commit": "$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
}
EOF
```
