# TODO: Per-Board Hardware Support

## Overview
Add per-board configuration to enable support for Intel, AMD, and ARM ChromeOS boards.
Currently ns only supports Intel boards (dedede, octopus, etc.) with hardcoded drivers.

## Problem
- `networking.nix`: Intel WiFi drivers only (`iwlmvm`, `ccm`)
- `power-management.nix`: Intel-only `intel_pstate=passive`
- `hardware.nix`: Intel thermal config (`thermald` with `x86_pkg_temp`)
- `luks2.nix`: Intel encryption (`aesni_intel`)

AMD and ARM boards need different drivers and configs.

## Board Architecture Reference

| Board | CPU | GPU | WiFi | Kernel | Audio |
|-------|-----|-----|------|--------|-------|
| dedede | Intel | Intel | Intel | 5.4+ | ❌ |
| octopus | Intel | Intel | Intel | 4.14 | ✅ |
| nissa | Intel | Intel | Intel | 5.10+ | ❌ |
| hatch | Intel | Intel | Intel | 5.4 | ❌ |
| brya | Intel | Intel | Intel | 5.10+ | ❌ |
| snappy | Intel | Intel | Intel | 5.4 | ✅ |
| zork | AMD | AMD | MediaTek | 5.4 | ❌ |
| grunt | AMD | AMD | Realtek | 4.14 | ❌ |
| jacuzzi | ARM (Mediatek) | Mali | MediaTek | 5.4 | ❌ |
| corsola | ARM (Mediatek) | Mali | MediaTek | 5.15 | ❌ |
| hana | ARM (Mediatek) | Mali | MediaTek | 5.4 | ❌ |
| trogdor | ARM (Qualcomm) | Adreno | Qualcomm | 5.4 | ❌ |

## Implementation Plan

### 1. Add Board Option
**File:** `shimboot_config/shimboot-options.nix`

```nix
board = lib.mkOption {
  type = lib.types.enum [ 
    "dedede" "octopus" "nissa" "hatch" "brya" "snappy"  # Intel
    "zork" "grunt"                                        # AMD
    "jacuzzi" "corsola" "hana" "trogdor"                  # ARM
  ];
  default = null;  # No default - MUST be set
  description = "ChromeOS board identifier (required)";
};
```

Add assertion to fail build if board not set:
```nix
config = lib.mkIf (config.shimboot.board == null) {
  assertions = [{
    assertion = false;
    message = ''
      shimboot.board must be set!
      
      Add to your config:
        shimboot.board = "dedede";
      
      Available boards:
        Intel: dedede, octopus, nissa, hatch, brya, snappy
        AMD:   zork, grunt
        ARM:   jacuzzi, corsola, hana, trogdor
      
      Run: cat /sys/class/dmi/id/product_name
      Or check: ./assemble-final.sh --board <board>
    '';
  }];
};
```

### 2. Create Board Database
**File:** `shimboot_config/boards/default.nix`

```nix
{ lib, ... }:
{
  # Intel boards (Jasper Lake/Apollo Lake/Alder Lake)
  dedede = {
    cpu = "intel";
    gpu = "intel";
    wifi = "intel";      # AX201/AX210
    wifiModules = [ "iwlmvm" "ccm" ];
    kernel = "5.4+";
    audio = false;
    touchscreen = true;
  };
  
  octopus = {
    cpu = "intel";
    gpu = "intel";
    wifi = "intel";
    wifiModules = [ "iwlmvm" "ccm" ];
    kernel = "4.14";      # Older kernel
    audio = true;
  };
  
  nissa = {
    cpu = "intel";
    gpu = "intel";
    wifi = "intel";
    wifiModules = [ "iwlmvm" "ccm" ];
    kernel = "5.10+";
    audio = false;
  };
  
  hatch = {
    cpu = "intel";
    gpu = "intel";
    wifi = "intel";
    wifiModules = [ "iwlmvm" "ccm" ];
    kernel = "5.4";
    audio = false;
    # Note: 5GHz WiFi may have issues
  };
  
  brya = {
    cpu = "intel";
    gpu = "intel";
    wifi = "intel";
    wifiModules = [ "iwlmvm" "ccm" ];
    kernel = "5.10+";
    audio = false;
  };
  
  snappy = {
    cpu = "intel";
    gpu = "intel";
    wifi = "intel";
    wifiModules = [ "iwlmvm" "ccm" ];
    kernel = "5.4";
    audio = true;
  };
  
  # AMD boards
  zork = {
    cpu = "amd";
    gpu = "amd";
    wifi = "mediatek";    # MT7921E
    wifiModules = [ "mt7921e" ];
    kernel = "5.4";
    audio = false;
  };
  
  grunt = {
    cpu = "amd";
    gpu = "amd";
    wifi = "realtek";     # May need manual driver
    wifiModules = [ ];
    kernel = "4.14";      # Older kernel
    audio = false;
  };
  
  # ARM boards (MediaTek/Qualcomm)
  jacuzzi = {
    cpu = "arm";
    gpu = "mali";
    wifi = "mediatek";
    wifiModules = [ ];
    kernel = "5.4";
    audio = false;
  };
  
  corsola = {
    cpu = "arm";
    gpu = "mali";
    wifi = "mediatek";
    wifiModules = [ ];
    kernel = "5.15";
    audio = false;
  };
  
  hana = {
    cpu = "arm";
    gpu = "mali";
    wifi = "mediatek";
    wifiModules = [ ];
    kernel = "5.4";
    audio = false;
  };
  
  trogdor = {
    cpu = "arm";
    gpu = "adreno";       # Qualcomm Adreno
    wifi = "qualcomm";    # ath10k
    wifiModules = [ "ath10k_pci" "ath10k_core" ];
    kernel = "5.4";
    audio = false;
    # Note: WiFi may have issues per README
  };
}
```

### 3. Pass Board Through Build Chain
**Files:** `flake.nix`, `flake_modules/raw-image.nix`

- Pass `board` from `assemble-final.sh` → flake → raw-image → NixOS config
- Make `board` available via `specialArgs` or `_module.args`

### 4. Update Modules to Use Board Config

#### networking.nix
```nix
{ config, lib, ... }:
let
  board = config.shimboot.board;
  boards = import ../boards/default.nix { inherit lib; };
  boardConfig = boards.${board};
in
{
  boot.kernelModules = lib.mkForce boardConfig.wifiModules;
  # ... rest
}
```

#### power-management.nix
```nix
boot.kernelParams = lib.mkIf (boardConfig.cpu == "intel")
  (lib.mkForce [ "intel_pstate=passive" ]);
```

#### hardware.nix
```nix
services.thermald = lib.mkIf (boardConfig.cpu == "intel") {
  enable = lib.mkForce true;
  # ... Intel thermal config
};

# AMD: no thermald, use different thermal approach
# ARM: completely different thermal subsystem
```

#### luks2.nix
```nix
boot.initrd.availableKernelModules = lib.mkIf (boardConfig.cpu == "intel")
  [ "dm-crypt" "dm-mod" "aesni_intel" "cryptd" ];
```

### 5. Consumer Configuration
**File:** `nixos-shimboot-config/user-config.nix` (or pnh equivalent)

```nix
{
  board = "dedede";  # REQUIRED - build fails if unset
}
```

## Build Flows

### Direct ns Build (assemble-final.sh)
```
./assemble-final.sh --board dedede
    ↓
flake.nix passes board to raw-image.nix
    ↓
raw-image.nix injects board into NixOS config
    ↓
NixOS modules read config.shimboot.board
    ↓
Conditional drivers loaded
```

### Consumer Build (nsc/pnh)
```
nsc/user-config.nix: board = "dedede"
    ↓
ns modules read config.shimboot.board
    ↓
Conditional drivers loaded
```

## Tasks

- [ ] 1. Add board option to shimboot-options.nix (required, assertion if unset)
- [ ] 2. Create boards/default.nix with board database
- [ ] 3. Pass board from assemble-final.sh → flake.nix → raw-image.nix → NixOS config
- [ ] 4. Update networking.nix (kernelModules conditional)
- [ ] 5. Update power-management.nix (intel_pstate conditional)
- [ ] 6. Update hardware.nix (thermald conditional)
- [ ] 7. Update luks2.nix (aesni_intel conditional)
- [ ] 8. Update consumer configs (nsc/pnh) with board = "dedede"
- [ ] 9. Test both build flows (direct + consumer)
- [ ] 10. Update ns README with board configuration docs

## Testing

### Test Intel Board (dedede)
```bash
./assemble-final.sh --board dedede --rootfs base
# Should: Load Intel WiFi drivers, enable intel_pstate, enable thermald
```

### Test AMD Board (zork)
```bash
./assemble-final.sh --board zork --rootfs base
# Should: Load MediaTek WiFi drivers, NO intel_pstate, NO thermald
```

### Test ARM Board (jacuzzi)
```bash
./assemble-final.sh --board jacuzzi --rootfs base
# Should: Load ARM-specific config, NO Intel-specific settings
```

### Test Missing Board
```bash
./assemble-final.sh --rootfs base  # No --board
# Should: Build FAILS with assertion error explaining required boards
```

## References

- Shimboot README: ~/shimboot/README.md (device compatibility table)
- ChromeOS board info: https://cros.download/
- Model → Board mapping: /sys/class/dmi/id/product_name (e.g., "Drawcia" → dedede)