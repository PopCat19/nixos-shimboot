## Shimboot Release (2025.12.08.1502-UTC)
Built from branch **dev** at commit `7942a50`.

### Configuration
- **Rootfs**: minimal
- **Drivers**: vendor
- **Firmware Upstream**: true

### Usage (replace BOARD with downloaded board name)

#### Linux/macOS
**⚠️ Requires root privileges (sudo/su)**

**Prerequisites:** Install zstd utility if not already available
- **Package Manager (preferred):**
  - Ubuntu/Debian: `sudo apt install zstd`
  - macOS: `brew install zstd` or `sudo port install zstd`
  - Fedora/RHEL: `sudo dnf install zstd` or `sudo yum install zstd`
- **Nix (if available):** `nix-shell -p zstd`
- **Manual install:** Download from https://facebook.github.io/zstd/

1. Extract the image:
```bash
zstd -d BOARD-shimboot-minimal.img.zst
```

2. Write to USB drive:
```bash
sudo dd if=BOARD-shimboot-minimal.img of=/dev/sdX bs=4M oflag=direct conv=fdatasync status=progress
```

#### Windows
1. Extract the image (use **7-Zip**):
   - Download and install 7-Zip: https://www.7-zip.org/
   - Right-click BOARD-shimboot-minimal.img.zst → 7-Zip → Extract Here

2. Write to USB drive (use **Rufus**):
   - Download Rufus: https://rufus.ie/
   - Select the extracted BOARD-shimboot-minimal.img file
   - Choose target USB drive
   - Click START and select 'DD Image mode' (writes image byte-for-byte, preserving GPT partition tables)