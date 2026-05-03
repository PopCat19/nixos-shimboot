
## Building an Image

```bash
sudo ./tools/build/assemble-final.sh --board <board> --rootfs minimal
```

The script builds Nix derivations and harvests ChromeOS drivers from the recovery image.

Assembles a partitioned disk image at `work/shimboot.img`.

Write it to USB:

```bash
sudo ./tools/write/write-shimboot-image.sh
```

<details>
<summary>Build options</summary>

- `--board`, one of the seven supported boards (required)
- `--rootfs minimal`, base config only (no personal desktop)
- `--drivers vendor`, store ChromeOS drivers on a separate vendor partition (default)
- `--drivers inject`, inject drivers directly into the rootfs
- `--drivers none`, skip driver harvesting
- `--drivers both`, vendor partition + inject
- `--dry-run`, test the build without destructive changes
- `--prewarm-cache`, fetch derivations from Cachix before building
- `--cleanup-rootfs`, prune old rootfs generations after build
- `--fresh`, start from beginning, ignore checkpoints

</details>

<details>
<summary>Tooling overview</summary>

| Directory | Purpose |
|-----------|---------|
| `tools/build/` | Image assembly, driver harvesting, partitioning |
| `tools/write/` | Safe USB flashing with interactive device selection |
| `tools/rescue/` | Boot troubleshooting, generation management, chroot recovery |
| `tools/lib/` | Shared logging, device detection, Nix helpers |
| `tools/inspect/` | Image inspection and log collection |

</details>


