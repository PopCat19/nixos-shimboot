# LLM Workspace Rule: SPEC.md Maintenance

## Trigger Conditions

Update `SPEC.md` when:
```
- flake.nix structure changes
- Configuration modules added/removed/relocated
- Build process modified
- Boot mechanism altered
- Hardware compatibility confirmed/denied
- Known constraints discovered
- Extension points created
```

## Update Protocol

### Section Mapping
```
File Changed                           → Update Section
─────────────────────────────────────────────────────────
flake.nix                              → 3 (Component Reference)
                                       → 4 (Build Pipeline)
shimboot_config/                       → 5 (Configuration System)
bootloader/                            → 6 (Boot Mechanism)
tools/                                 → 4 (Build Pipeline)
                                       → 10 (Quick Reference)
Hardware test results                  → 1 (Tested Hardware)
                                       → 7 (Known Constraints)
New helper script                      → 8 (Extension Points)
                                       → 10 (Quick Reference)
Build artifact structure               → 3 (Component Reference)
                                       → 10 (File Paths)
```

### Update Rules

**Preserve:**
```
- Tree/node visualizations (no flowcharts)
- Token-efficient list formatting
- Copy-pasteable code blocks
- Independent section comprehension
- Existing heading hierarchy
```

**Avoid:**
```
- Cross-references (e.g., "see Section X")
  └─ Instead: Duplicate relevant info
  
- Time markers (e.g., "recently", "upcoming")
  └─ Instead: "current state", "exists"
  
- Priority markers (e.g., "NEW", "IMPORTANT")
  └─ Instead: Factual descriptions
  
- Unverified claims (e.g., "should work")
  └─ Instead: "tested working", "known to fail"
  
- Prose paragraphs
  └─ Instead: Bullet lists, code blocks
```

**Format:**
```
Code blocks:
├─ Use triple backticks with language identifier
├─ Include comments for clarity
└─ Ensure copy-pasteable (no line numbers, no prompt chars)

Trees:
├─ Use box-drawing characters (├─ └─ │)
├─ Indent consistently (3 spaces)
└─ Keep max depth ≤ 4 levels

Lists:
├─ Use - for unordered
├─ Use numbers for sequences
└─ Use └─ for tree continuations
```

### Section-Specific Instructions

**Section 1 (Project Identity):**
```
Update when: Hardware tested, support matrix changes
Keep: Tested Hardware subsection current
Add: New board only if personally verified working
Remove: Unverified "infrastructure only" claims after testing
```

**Section 3 (Component Reference):**
```
Update when: flake.nix outputs change
Action: Regenerate Build Artifacts tree from actual flake outputs
Command: nix flake show --json | jq '.packages.x86_64-linux | keys'
Format: Match existing tree structure
```

**Section 4 (Build Pipeline):**
```
Update when: assemble-final.sh modified, new tools/ scripts
Action: Update Build Graph tree
Verify: Trace actual file dependencies
Format: Use → for data flow, ├─ for alternatives
```

**Section 5 (Configuration System):**
```
Update when: shimboot_config/ structure changes
Action: Update Module Structure tree
Method: ls -R shimboot_config/ | convert to tree
Include: Only .nix files and directories
```

**Section 6 (Boot Mechanism):**
```
Update when: bootstrap.sh modified, boot sequence changes
Action: Update Execution Tree
Format: Use └─ for single child, ├─ for multiple
Depth: Show full PID 1 chain to user session
```

**Section 7 (Known Constraints):**
```
Update when: New hardware limitation discovered
Action: Add to appropriate subsection
Evidence: Include actual error messages or test results
Format: Use tables for support matrices
```

**Section 8 (Extension Points):**
```
Update when: New customization method available
Action: Add subsection with example
Include: Required files, test command, expected output
Format: Match existing subsection structure
```

**Section 10 (Quick Reference):**
```
Update when: Common commands change, file paths relocate
Action: Update relevant subsection
Test: Verify commands are currently working
Format: Use └─ for command descriptions
```

## Validation Checklist

Before committing SPEC.md changes:
```
□ Run: grep -E 'NEW|IMPORTANT|TODO|FIXME' SPEC.md
  └─ Result: No matches

□ Run: grep -E 'Section [0-9]|see above|see below' SPEC.md
  └─ Result: No cross-references outside section headers

□ Check: All code blocks have triple backticks
  └─ Count: Opening ``` == Closing ```

□ Check: All trees use consistent box-drawing
  └─ Pattern: ├─ └─ │ only

□ Verify: Each section independently comprehensible
  └─ Test: Read section in isolation

□ Verify: No unverified claims
  └─ Pattern: "should", "will", "might" → replace with facts

□ Verify: File paths exist
  └─ Test: Find examples in SPEC.md | xargs ls

□ Verify: Commands work
  └─ Test: Extract commands | xargs -I {} sh -c '{}'
```

## Example Diff Pattern

**Good Change:**
```diff
main_configuration/
├─ configuration.nix
└─ home_modules/
   ├─ home.nix
+  ├─ wezterm.nix        - Terminal config
   ├─ kitty.nix          - Terminal config
```

**Bad Change:**
```diff
main_configuration/
├─ configuration.nix
└─ home_modules/
   ├─ home.nix
+  ├─ wezterm.nix        - NEW! Better than kitty! (see Section 5.3)
   ├─ kitty.nix          - Terminal config (deprecated)
```

## Conflict Resolution

If update creates inconsistency:
```
1. Identify affected sections (use Section Mapping)
2. Update all affected sections atomically
3. Prefer duplication over cross-reference
4. Test using Validation Checklist
```

Example:
```
Change: New helper script added to base_configuration/
Affected: Section 5 (structure), Section 8 (extension), Section 10 (commands)
Action: Update all three with duplicated relevant info
```

## Edge Cases

**Temporary features:**
```
Mark as: (experimental)
Location: End of description
Example: "ChromeOS boot (experimental)"
Remove "experimental" only after confirmed working
```

**Version-specific info:**
```
Avoid: "NixOS 24.11 includes..."
Instead: "Current configuration includes..."
Context: Let git history track version changes
```

**Performance claims:**
```
Avoid: "Fast", "Slow", "Efficient"
Instead: Specific measurements or "Untested"
Example: "~6-8GB" not "Small footprint"
```