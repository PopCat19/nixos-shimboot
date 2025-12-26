# Rule Writing Guidelines

Guidelines for creating new rule files in `.kilocode/rules` directory.

## File Naming

- Use kebab-case: `descriptive-name.md`
- Names should reflect the rule's primary purpose
- Avoid generic names like `rules.md` or `guidelines.md`
- Examples: `dry-refactor.md`, `module.md`, `llm-note.md`

## Content Structure

### Required Sections
1. **Title**: Clear, descriptive H1 header
2. **Purpose**: Brief description of the rule's scope
3. **Main Content**: Organized into logical subsections
4. **Validation**: Commands or checks for rule compliance

### Optional Sections
- **Examples**: Practical code samples or usage patterns
- **Checklist**: Actionable items for verification
- **Reference Commands**: Relevant CLI commands

## Formatting Standards

### Headers
- H1: `# Rule Name`
- H2: `## Section Name`
- H3: `### Subsection Name`
- Avoid decorative elements (emojis, excessive punctuation)

### Code Blocks
- Use fenced triple-backticks: ```lang
- Include language specification for syntax highlighting
- Keep examples concise and focused

### Lists
- Use numbered lists for processes: `1. Step one`
- Use dash lists for items: `- Item`
- Use checkboxes for checklists: `- [ ] Task`

## Token Efficiency Principles

### Content Guidelines
- **Essential Information Only**: Remove redundant explanations
- **Action-Oriented**: Focus on what to do, not why
- **Concise Examples**: Show minimum viable code patterns
- **Direct Language**: Avoid conversational tone

### Structure Guidelines
- **Maximum 100 characters per line**
- **Single blank line between major sections**
- **No excessive whitespace or decorative elements**

## Content Organization Patterns

### Pattern 1: Process-Oriented
```markdown
# Rule Name

## Process
1. Step one
2. Step two
3. Step three

## Examples
```lang
# Example code
```

## Validation
```bash
# Validation command
```
```

### Pattern 2: Template-Oriented
```markdown
# Rule Name

## Template
```lang
# Template code
```

## Required Fields
- Field 1: Description (required/optional)
- Field 2: Description (required/optional)

## Style Rules
- Rule 1
- Rule 2
```

### Pattern 3: Reference-Oriented
```markdown
# Rule Name

## Key Concepts
- Concept 1
- Concept 2

## Examples
```lang
# Example 1
```

```lang
# Example 2
```

## Reference Commands
```bash
# Command 1
# Command 2
```
```

## Quality Criteria

### Before Creating a New Rule
- [ ] Content doesn't fit existing rule files
- [ ] New rule serves distinct purpose
- [ ] Content is substantial enough for separate file
- [ ] Rule follows established naming convention

### Before Finalizing Rule
- [ ] Content follows token efficiency principles
- [ ] Examples are minimal and focused
- [ ] Language is direct and actionable
- [ ] Structure matches one of the established patterns
- [ ] All code blocks have language specifications
- [ ] Headers follow H1 → H2 → H3 hierarchy

### Validation Checklist
- [ ] File name follows kebab-case convention
- [ ] Content is organized in logical sections
- [ ] Examples are concise and practical
- [ ] Validation commands are included where applicable
- [ ] Language is consistent with existing rules
- [ ] Line length doesn't exceed 100 characters
- [ ] No excessive decorative elements

## Integration with Existing Rules

### Cross-References
- Reference related rule files when relevant
- Use consistent terminology across all rules
- Avoid duplicating content from existing rules

### Complementary Content
- Rules should complement, not compete
- New rules should enhance overall system understanding
- Maintain consistency with established patterns

## Maintenance

### Updates
- Follow same guidelines when modifying existing rules
- Preserve essential content while improving clarity
- Maintain backward compatibility for references

### Versioning
- Rule changes don't require version numbers
- Git history serves as change tracking
- Update related rules when making breaking changes