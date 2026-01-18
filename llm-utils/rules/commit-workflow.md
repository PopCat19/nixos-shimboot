# Commit Workflow

## Format

```
<type>(scope): <action> <summary>
```

## Types

| Type | Meaning |
|------|----------|
| feat | New feature or capability |
| fix | Bug correction |
| refactor | Code structure change without functional change |
| docs | Documentation or comments only |
| style | Whitespace or formatting only |
| test | Tests addition or modification |
| chore | Maintenance or dependency updates |
| perf | Performance improvement |
| revert | Undo previous commit |

## Scope Rules

- Scope = file or folder name (`basename` only)
- Up to 3 comma-separated scopes
- Use directory name for large changes
- Lowercase only
- Omit extensions unless ambiguous

Good → `(flake.nix)`
Good → `(networking,hardware)`
Bad → `(shimboot_config/base_configuration/networking.nix)`

## Action Verbs

| Verb | Use |
|------|-----|
| add | Introduce new content |
| remove | Delete file or behavior |
| update | Modify existing content |
| fix | Correct defective logic |
| refactor | Rearrange code structure |
| implement | Complete or finalize feature |
| enable | Activate behavior |
| disable | Deactivate behavior |
| configure | Set up configuration |
| integrate | Combine components |

## Summary Rules

- Imperative mood ("add", not "added")
- Lowercase first word
- No ending punctuation
- Max 72 characters
- Describe *what*, not *why*

Good → `add zram swap configuration`
Bad → `Added ZRAM support for better performance.`

## Body Guidelines

Add body when:
- The reasoning is non-obvious
- There is a breaking change
- The commit encompasses multiple sub-edits
- There are notable side effects

Formatting:
- Wrap each line at 72 chars
- One blank line between header and body
- Use list bullets for multiple points

## Examples

**Single File**
```
feat(zram.nix): add zram swap configuration

- Enable zram
- Configure memoryPercent to 100
- Load kernel module
```

**Multiple Files**
```
refactor(helpers): split filesystem and setup helpers

- Move expand_rootfs
- Create setup-helpers.nix
- Update helper imports
```

**Directory Scope**
```
feat(home_modules): add wezterm terminal configuration

- Configure Rose Pine theme
- Add font settings
```

**Fix**
```
fix(assemble-final.sh): correct vendor bind order

Drivers were bound after pivot_root, causing failures.
Now bound before systemd start.
```

**Chore**
```
chore(flake): update nixpkgs input to unstable
```

**Docs**
```
docs(SPEC): update section 5 module structure
```

**Refactor**
```
refactor(base_configuration): consolidate helper modules
```

## Workflow Practice

**Commit When**
- Single logical change complete
- Tests or `flake check` pass
- Feature milestone achieved
- Before switching task context

**Avoid**
- "WIP" or temporary commits
- Mixed unrelated edits
- Broken or untested changes

## Git Tracking Policy

**Always Track**
```
*.nix, *.sh, *.fish, *.conf, *.md, LICENSE
manifests/*-manifest.nix
flake.lock
```

**Never Track**
```
work/, result*, *.img, *.bin, *.zip, .temp/
harvested/, .direnv/, gcroots/
.vscode/, .idea/, *.swp, *~, .DS_Store
.envrc.local, local-config.nix
```

## Flake Validation

**Run Before Commit**
```bash
nix flake check --impure --accept-flake-config
```

**Typical Output**
```
checking flake output 'nixosConfigurations'...
checking flake output 'packages'...
evaluation successful.
```

**Use shortcut**
```bash
alias fcheck='nix flake check --impure --accept-flake-config'
```

**Optional Quick Checks**
```bash
nix flake show
nix build .#raw-rootfs --dry-run
```

**If error**
1. Read trace line and fix syntax or import
2. Re-run until clean
3. Never commit failing check unless flagged `[skip-check]`

## Validation

**Regex**
```bash
^(feat|fix|docs|style|refactor|test|chore|perf|revert)\([^)]+\): [a-z].+[^.]$
```

**Pre-Commit Hook**
```bash
#!/bin/bash
msg=$(cat "$1")
pattern='^(feat|fix|docs|style|refactor|test|chore|perf|revert)\([^)]+\): [a-z].+[^.]$'

if ! grep -Eq "$pattern" "$1"; then
  echo "❌ Invalid commit message."
  echo "Use: <type>(scope): <action> <summary>"
  exit 1
fi
```

## Quick Reference

| Type | Example |
|------|----------|
| feat | `feat(flake): add new board support` |
| fix | `fix(networking): repair wlan rfkill blocking` |
| docs | `docs(CONVENTIONS): clarify header format rules` |
| refactor | `refactor(helpers): reorganize filesystem utils` |
| chore | `chore(flake): bump nixpkgs unstable` |
