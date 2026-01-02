# Comment Cleanup Guidelines

## Purpose
Remove redundant and unnecessary comments while preserving essential documentation in rule files.

## Cleanup Patterns

### Redundant Header Comments
```markdown
# Rule Name

## Purpose
Brief description of the rule's scope
```

### Inline Code Comments
```markdown
## Examples
```lang
# Example code  # Remove: Obvious statement
```

## Validation
```bash
# Command 1  # Remove: Redundant explanation
```

## Cleanup Process

### 1. Identify Redundant Content
- Comments that state the obvious
- Duplicate information across sections
- Explanatory text that repeats section headers
- Placeholder comments in templates

### 2. Remove Unnecessary Elements
- `// Example code` → Remove comment, keep code
- `# This does X` → Keep only if X is not obvious
- Redundant section descriptions
- Self-explanatory command comments

### 3. Preserve Essential Information
- Purpose statements
- Required field descriptions
- Validation commands
- Cross-references to other rules

## Before/After Examples

### Before
```markdown
## Process
1. Step one
2. Step two
3. Step three

## Examples
```lang
# Example code showing pattern
```

## Validation
```bash
# Validation command to check compliance
```
```

### After
```markdown
## Process
1. Step one
2. Step two
3. Step three

## Examples
```lang
# Example code showing pattern
```

## Validation
```bash
nix flake check --impure --accept-flake-config
```
```

## Token Efficiency Rules

### Remove When
- Comment duplicates the code/action
- Explanation adds no new information
- Text is self-evident from context
- Comment is purely decorative

### Keep When
- Provides non-obvious context
- Explains rationale behind decisions
- Links to external resources
- Warns about potential issues

## Validation
```bash
# Check for redundant comments
grep -r "# Example" .kilocode/rules/
grep -r "# Command" .kilocode/rules/

# Validate line length
awk 'length > 100 {print NR ": " $0}' .kilocode/rules/*.md