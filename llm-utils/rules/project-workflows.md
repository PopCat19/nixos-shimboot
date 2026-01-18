# Project Workflows

## Don't Orphan Modules

Ensure all module files are properly imported and referenced in the configuration.

### Detection

```bash
# List all .nix files in module directories
find configuration/home/home_modules configuration/system/system_modules -name "*.nix"

# Cross-reference against imports in parent files
grep -r "import" configuration/home/home.nix configuration/system/configuration.nix
```

### Common Orphan Patterns

- Module created but never added to imports list
- Module removed from imports but file not deleted
- Module moved to different directory without updating imports

### Prevention

**When Creating New Modules**
1. Create module file with proper header
2. Add import to parent configuration immediately
3. Run `nix flake check` to verify integration

**When Removing Modules**
1. Remove import from parent configuration
2. Delete the module file
3. Verify no other files reference the removed module

### Import Checklist

**System Modules**
- [ ] Added to `configuration/system/configuration.nix` imports
- [ ] Or added to host-specific `hosts/<host>/configuration.nix` imports

**Home Modules**
- [ ] Added to `configuration/home/home.nix` imports
- [ ] Or added to host-specific `hosts/<host>/home.nix` imports

## Use Context7 for Documentation

Context7 MCP server provides up-to-date library and framework documentation.

### When to Use

- Looking up API signatures for unfamiliar packages
- Checking NixOS option syntax and available attributes
- Verifying Home Manager module options
- Understanding library function parameters
- Confirming package configuration patterns

### Usage Pattern

**Before Writing Module Code**
1. Query Context7 for relevant documentation
2. Verify option names and types
3. Check for deprecated or renamed options
4. Confirm package attribute paths

**Example Queries**
- NixOS networking options
- Home Manager programs.fish configuration
- Hyprland window rules syntax
- systemd service options

### Benefits

- Current documentation (not training data cutoff)
- Version-specific information
- Accurate option types and defaults
- Reduces configuration errors

## SPEC.md Maintenance

### Trigger Conditions

Update `SPEC.md` when:
- flake.nix structure changes
- Configuration modules added/removed/relocated
- Build process modified
- Boot mechanism altered
- Hardware compatibility confirmed/denied
- Known constraints discovered
- Extension points created

### Section Mapping

```
File Changed              → Update Section
────────────────────────────────────────────────
flake.nix                 → 3 (Component Reference)
                          → 4 (Build Pipeline)
shimboot_config/          → 5 (Configuration System)
bootloader/               → 6 (Boot Mechanism)
tools/                    → 4 (Build Pipeline)
                          → 10 (Quick Reference)
Hardware test results     → 1 (Tested Hardware)
                          → 7 (Known Constraints)
New helper script         → 8 (Extension Points)
                          → 10 (Quick Reference)
Build artifact structure  → 3 (Component Reference)
                          → 10 (File Paths)
```

### Update Rules

**Preserve:**
- Tree/node visualizations
- Token-efficient list formatting
- Copy-pasteable code blocks
- Independent section comprehension
- Existing heading hierarchy

**Avoid:**
- Cross-references (e.g., "see Section X")
- Time markers (e.g., "recently", "upcoming")
- Priority markers (e.g., "NEW", "IMPORTANT")
- Unverified claims (e.g., "should work")
- Prose paragraphs → Use bullet lists, code blocks

**Format:**
- Code blocks: Triple backticks with language identifier
- Trees: Box-drawing characters (├─ └─ │), 3-space indent, max depth 4
- Lists: - for unordered, numbers for sequences, └─ for continuations

### Section-Specific Instructions

**Section 1 (Project Identity):**
Update when hardware tested, support matrix changes. Add new board only if personally verified working.

**Section 3 (Component Reference):**
Regenerate Build Artifacts tree from actual flake outputs:
```bash
nix flake show --json | jq '.packages.x86_64-linux | keys'
```

**Section 4 (Build Pipeline):**
Update Build Graph tree when assemble-final.sh modified. Trace actual file dependencies.

**Section 5 (Configuration System):**
Update Module Structure tree when shimboot_config/ changes:
```bash
ls -R shimboot_config/
```

**Section 6 (Boot Mechanism):**
Update Execution Tree when bootstrap.sh modified. Show full PID 1 chain to user session.

**Section 7 (Known Constraints):**
Add to appropriate subsection with actual error messages or test results. Use tables for support matrices.

**Section 8 (Extension Points):**
Add subsection with example when new customization method available. Include required files, test command, expected output.

**Section 10 (Quick Reference):**
Update relevant subsection when commands change or paths relocate.

### Validation Checklist

```bash
# No priority markers
grep -E 'NEW|IMPORTANT|TODO|FIXME' SPEC.md

# No cross-references outside headers
grep -E 'Section [0-9]|see above|see below' SPEC.md

# Verify code blocks
grep -c '```' SPEC.md  # Should be even number

# Verify box-drawing consistency
grep -E '[├─│└]' SPEC.md | grep -v '├─\|└─\|│'

# Verify file paths exist
grep -oP '(?<=\`)[^`]*(?=\.nix|\.sh|\.md)`' SPEC.md | xargs ls
```

## Validation

```bash
nix flake check --impure --accept-flake-config
for host in nixos0 surface0 thinkpad0; do
  nixos-rebuild dry-run --flake .#$host
done
```
