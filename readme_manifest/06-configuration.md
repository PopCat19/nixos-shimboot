
## Configuration

This repository is the **build system + ChromeOS hardware abstraction layer**. Personal desktop configuration belongs in a separate repo.

```
nixos-shimboot/                       # build system + ChromeOS HAL
├── flake.nix                         # exports nixosModules.chromeos
├── flake_modules/                    # image building, kernel extraction
├── shimboot_config/
│   ├── base_configuration/           # boot, fs, hardware, users
│   ├── boards/                       # per-board hardware database
│   ├── user-config.nix               # shared hostname, username
│   ├── shimboot-options.nix          # shimboot.headless toggle
│   └── nix-options.nix               # allowUnfree predicate
├── bootloader/                       # initramfs bootstrap menu
├── patches/                          # systemd ChromeOS mount patch
├── tools/
│   ├── build/                        # image assembly, driver harvesting
│   ├── write/                        # safe USB flashing
│   └── rescue/                       # boot troubleshooting, chroot recovery
└── manifests/                        # ChromeOS shim chunk manifests
```

The tree is designed to be self-documenting. Module headers with `Purpose:` blocks serve as in-code docs — explore by directory rather than relying on external references.

This repo follows the [dev-mini](https://github.com/PopCat19/dev-conventions) conventions.

```
nixos-shimboot-config/                # companion repo, personal desktop
├── flake.nix                         # imports shimboot as flake input
└── main/                             # reference template (fork this)
```

External flakes import the ChromeOS module as a hardware layer:

```nix
inputs.shimboot.url = "github:PopCat19/nixos-shimboot";

modules = [
  shimboot.nixosModules.chromeos      # ChromeOS boot, fs, hardware
  ./my-config.nix                     # DE, packages, home-manager
];
```


