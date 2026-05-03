
## Limitations

- No suspend support (ChromeOS kernel limitation)
- Audio only works on octopus and snappy; other boards need USB/Bluetooth audio
- hatch: 5 GHz WiFi networks may have connectivity issues
- trogdor: WiFi may be unreliable
- `nixos-rebuild` requires `--option sandbox false` on kernels < 5.6 (missing namespace support)
- bwrap/Steam: ChromeOS LSM blocks tmpfs mounts; workaround available below


