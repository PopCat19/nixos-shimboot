# DRY Refactoring Outline

## Process
1. Add module header with Purpose, Dependencies, This module sections
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
rsnaTimeout = 60;
wifi."dot11RSNAConfigSATimeout" = rsnaTimeout;
wifi."dot11RSNAConfigPairwiseUpdateTimeout" = rsnaTimeout;
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
- [ ] No inline comments for values