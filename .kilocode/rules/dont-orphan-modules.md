# Don't Orphan Modules

Ensures all module files are properly imported and referenced in the configuration.

## Purpose

Prevent orphaned modules (files that exist but are never imported) which waste disk space
and create confusion about what's active in the configuration.

## Detection

### Check for Orphaned Modules
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

## Prevention

### When Creating New Modules
1. Create module file with proper header
2. Add import to parent configuration immediately
3. Run `nix flake check` to verify integration

### When Removing Modules
1. Remove import from parent configuration
2. Delete the module file
3. Verify no other files reference the removed module

## Import Checklist

### System Modules
- [ ] Added to [`configuration/system/configuration.nix`](configuration/system/configuration.nix) imports
- [ ] Or added to host-specific [`hosts/<host>/configuration.nix`](hosts/) imports

### Home Modules
- [ ] Added to [`configuration/home/home.nix`](configuration/home/home.nix) imports
- [ ] Or added to host-specific [`hosts/<host>/home.nix`](hosts/) imports

## Validation

```bash
# Check flake integrity
nix flake check --impure --accept-flake-config

# Dry-run all hosts
for host in nixos0 surface0 thinkpad0; do
  nixos-rebuild dry-run --flake .#$host
done
```
