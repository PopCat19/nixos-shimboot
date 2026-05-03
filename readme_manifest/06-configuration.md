
## Configuration

This repository is the **build system + ChromeOS hardware abstraction layer**. Personal desktop configuration belongs in a separate repo.

```
nixos-shimboot/                       # build system + ChromeOS HAL
├── flake.nix                         # exports nixosModules.chromeos
├── flake_modules/                    # image building, kernel extraction
├── shimboot_config/
│   ├── base_configuration/           # boot, fs, hardware, users
│   └── user-config.nix               # shared hostname, username
└── tools/

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


