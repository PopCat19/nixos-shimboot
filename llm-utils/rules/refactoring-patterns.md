# Refactoring Patterns

## Process

1. Add module header with Purpose, Rationale, Related, Note sections
2. Extract repeated values to `let...in` block
3. Replace inline values with variable references
4. Flatten single-key attribute sets using dot notation
5. Consolidate single-attribute blocks

## Patterns

### Port Centralization
```nix
{...}: let
  ports = {
    ssh = 22;
    syncthing = 53317;
    custom = 30071;
    dns = 53;
    dhcp = 67;
  };
in {
  networking.firewall.allowedTCPPorts = [ports.ssh ports.syncthing];
  networking.firewall.allowedUDPPorts = [ports.syncthing ports.dns];
}
```

### Timeout/Limit Centralization
```nix
{...}: let
  rsnaTimeout = 60;
in {
  wifi."dot11RSNAConfigSATimeout" = rsnaTimeout;
  wifi."dot11RSNAConfigPairwiseUpdateTimeout" = rsnaTimeout;
}
```

### Flattening Attribute Sets
```nix
# Before:
settings = {
  device = {"wifi.scan-rand-mac-address" = "no";};
  connection = {"wifi.powersave" = 2;};
};

# After:
settings = {
  device."wifi.scan-rand-mac-address" = "no";
  connection."wifi.powersave" = 2;
};
```

## Comment Cleanup

### Remove
- Comments that are a plain-English translation of the code
- Duplicate information across sections
- Explanatory text that repeats section headers
- Self-explanatory command comments

Examples to remove:
- `// Enable service` → the code `enable = true` is self-evident
- `# Sets timeout to 30s` → redundant with `timeout = 30`
- `# Example code` → obvious from context

### Keep
- Provides non-obvious rationale (the "Why")
- Explains magic numbers or specific hardware workarounds
- Links to external resources
- Warns about potential issues

## Token Efficiency

### Remove (Prevent "Comment Lies")
- Comment duplicates the code/action
- Explanation adds no new information
- Text is self-evident from context

### Keep (Preserve Intent)
- Non-obvious rationale
- Magic numbers or hardware workarounds
- External resource links
- Potential issue warnings

## Validation

```bash
nix flake check --impure --accept-flake-config
for host in nixos0 surface0 thinkpad0; do
  nixos-rebuild dry-run --flake .#$host
done
```

## Checklist

- [ ] Repeated values extracted
- [ ] Module header added
- [ ] Flake check passes
- [ ] All hosts evaluate
- [ ] Variables self-documenting
- [ ] Redundant comments removed
- [ ] Only rationale-preserving comments kept
