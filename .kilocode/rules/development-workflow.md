# LLM Development Workflow Guidelines

This document outlines best practices for LLM-assisted development in the shimboot project, based on successful patterns observed in recent refactoring work.

## Core Workflow Pattern

### 1. Task Analysis & Planning
- **Use TODO lists** for complex multi-step tasks to track progress systematically
- **Break down tasks** into clear, achievable steps before starting implementation
- **Analyze file structure** and dependencies before making changes

### 2. Iterative Development Cycle
```
Analyze → Plan → Implement → Test → Commit → Repeat
```

#### Step-by-Step Process:
1. **Analyze the task** and set clear goals
2. **Create a TODO list** for multi-step tasks using `update_todo_list`
3. **Work through steps iteratively**:
   - Make targeted changes using appropriate tools
   - Test changes (e.g., `nix flake check`)
   - Update TODO status as you progress
4. **Commit frequently** with clear, conventional commit messages
5. **Verify flake integrity** after each major change

### 3. Tool Usage Best Practices

#### File Operations:
- **Use `read_file`** to understand existing code before making changes
- **Use `apply_diff`** for surgical edits to existing files
- **Use `write_to_file`** only for creating new files or complete rewrites
- **Use `search_files`** to understand code patterns and dependencies

#### System Operations:
- **Use `execute_command`** for running commands, with clear explanations
- **Test changes** with `nix flake check` after modifications
- **Commit changes** with `git add . && git commit -m "message"`

### 4. Commit Strategy

#### Conventional Commits:
```
type[optional scope]: description

[optional body]

[optional footer]
```

#### Types:
- `feat:` - New features
- `fix:` - Bug fixes
- `refactor:` - Code restructuring
- `docs:` - Documentation changes
- `style:` - Code style changes
- `test:` - Testing changes
- `chore:` - Maintenance tasks

#### Examples:
```
fix: update manifest path and add octopus manifest
refactor: organize scripts into tools/ directory for better organization
feat: add manifests for all supported ChromeOS boards
```

### 5. Quality Assurance

#### Always verify:
- **Flake integrity**: Run `nix flake check` after changes
- **Git status**: Ensure working tree is clean before commits
- **Dependencies**: Update all references when moving/renaming files
- **CI/CD**: Ensure GitHub workflows still function

#### Testing workflow:
1. Make changes
2. Run `nix flake check`
3. If passing, commit changes
4. If failing, analyze errors and fix iteratively

### 6. Project Organization

#### Directory Structure Guidelines:
- **Keep root clean**: Main workflow scripts in root, utilities in subdirs
- **Group by function**: Related files in dedicated directories
- **Use descriptive names**: `tools/` instead of `scripts/`, `snapshots/` for state files
- **Update references**: When moving files, update all imports and references

#### Example Structure:
```
├── main-workflow-scripts.sh    # Core functionality
├── tools/                      # Utility scripts
├── manifests/                  # Data/configuration files
├── snapshots/                  # Generated artifacts
└── flake_modules/              # Nix-specific modules
```

## Benefits of This Workflow

1. **Systematic Progress**: TODO lists prevent losing track of complex tasks
2. **Frequent Validation**: Regular flake checks catch issues early
3. **Clean Commits**: Conventional commits make history readable
4. **Iterative Safety**: Small, tested changes reduce risk
5. **Clear Organization**: Well-structured directories aid newcomers

## Checklist for LLM-Assisted Tasks

- [ ] Analyze task requirements and dependencies
- [ ] Create TODO list for multi-step tasks
- [ ] Work through steps systematically
- [ ] Test changes with `nix flake check`
- [ ] Commit with conventional messages
- [ ] Update documentation as needed
- [ ] Verify all references are updated when moving files

This workflow has proven effective for maintaining code quality and project organization in the shimboot project.