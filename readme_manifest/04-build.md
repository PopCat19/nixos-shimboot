
## Building an Image

Two build paths are available: the shell orchestrator (`assemble-final.sh`) and pure-Nix derivations.

### Nix derivation (pure, sandboxed)

```bash
# Base desktop image
nix build .#shimboot-image-<board>

# Headless SSH-only
nix build .#shimboot-image-<board>-headless

# LUKS2-capable (wrapping is post-build)
nix build .#shimboot-image-<board>-luks
nix build .#shimboot-image-<board>-headless-luks
```

The Nix build runs fully in the sandbox — no sudo, no loop devices. Store optimization
(hard-link dedup) and git self-repair metadata are applied at build time via `debugfs`
+ `fakeroot`.

LUKS2 variants include static `cryptsetup` in the initramfs and expect
`/dev/mapper/rootfs`. Actual LUKS container wrapping must be done post-build
(dm-crypt is unavailable in the Nix sandbox):

```bash
sudo ./tools/write/wrap-luks.sh --image $(nix eval .#shimboot-image-<board>-luks.outPath --raw)/shimboot.img
```

Output is a single file at `result/shimboot.img`. Write it to USB:

```bash
sudo ./tools/write/write-shimboot-image.sh
```

### Shell orchestrator (legacy, all-in-one)

```bash
sudo ./tools/build/assemble-final.sh --board <board> --rootfs base
```

The script builds Nix derivations and harvests ChromeOS drivers from the recovery image.
Assembles a partitioned disk image at `work/shimboot.img`.

<details>
<summary>Shell build options</summary>

- `--board`, one of the seven supported boards (required)
- `--rootfs base`, base config (system, boot, hardware)
- `--drivers vendor`, store ChromeOS drivers on a separate vendor partition (default)
- `--drivers inject`, inject drivers directly into the rootfs
- `--drivers none`, skip driver harvesting
- `--drivers both`, vendor partition + inject
- `--dry-run`, test the build without destructive changes
- `--prewarm-cache`, fetch derivations from Cachix before building
- `--luks`, enable LUKS2 encryption for rootfs partition
- `--luks-password PASS`, passphrase for LUKS2 (skips interactive prompt)
- `--push-to-cachix`, push built derivations to Cachix
- `--firmware-upstream`/`--no-firmware-upstream`, control upstream firmware (default: enabled)
- `--cleanup-keep N`, keep last N generations during cleanup (default: 3)

</details>

### WiFi for headless images

Headless variants need WiFi to be usable via SSH. Two options:

1. **Via `secrets.nix`** (gitignored) — create `shimboot_config/secrets.nix`:
   ```nix
   { wifi = { ssid = "MyNetwork"; psk = "password"; }; }
   ```
   Build with `path:` fetcher to include the untracked file:
   ```bash
   nix build "path:$PWD#shimboot-image-<board>-headless"
   ```

2. **Via derivation parameter** — pass credentials directly (pure, no secrets.nix needed):
   ```nix
   mkShimbootImage { headless = true; wifi = { ssid = "MyNetwork"; psk = "password"; }; }
   ```

<details>
<summary>Tooling overview</summary>

| Directory | Purpose |
|-----------|---------|
| tools/build/ | Image assembly, driver harvesting, partitioning |
| tools/write/ | Safe USB flashing, LUKS wrapping |
| tools/rescue/ | Boot troubleshooting, generation management, chroot recovery |
| tools/lib/ | Shared logging, device detection, Nix helpers |
| tools/inspect/ | Image inspection and log collection |

</details>
