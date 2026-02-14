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
