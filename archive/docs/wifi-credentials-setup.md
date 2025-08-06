# WiFi Credentials Autoconnect Setup

This document describes how to set up WiFi autoconnect using a separate derivation for credentials in the NixOS shimboot system.

## Overview

The WiFi credentials system allows you to securely configure WiFi autoconnect for a single network with WPA2/WPA3 personal security. The credentials are stored in a separate JSON file that is excluded from version control for security.

## Files Structure

- `wifi-credentials.json.example` - Example configuration file
- `wifi-credentials.json` - Actual credentials file (gitignored)
- `wifi-credentials-derivation.nix` - Nix derivation for generating NetworkManager profiles
- `system_modules/wifi-credentials.nix` - NixOS module for WiFi credentials integration

## Setup Instructions

### 1. Create WiFi Credentials File

Copy the example file and create your actual credentials file:

```bash
cp wifi-credentials.json.example wifi-credentials.json
```

Edit the `wifi-credentials.json` file with your WiFi network information:

```json
{
  "wifi": {
    "ssid": "YourNetworkName",
    "psk": "YourPassword",
    "security": "wpa2-psk"
  }
}
```

### 2. Security Options

The `security` field supports the following values:
- `wpa2-psk` - WPA2 Personal (default)
- `wpa3-sae` - WPA3 SAE (Simultaneous Authentication of Equals)

### 3. Enable WiFi Autoconnect

The WiFi credentials system is enabled by default in `user-config.nix`. To verify or modify:

```nix
# In user-config.nix
network = {
  # ... other network settings ...
  
  # WiFi credentials autoconnect
  wifiCredentials = {
    enable = true;
    credentialsFile = ./wifi-credentials.json;
  };
};
```

### 4. Build and Deploy

Build your NixOS system as usual:

```bash
nixos-rebuild switch
```

Or if you're building the shimboot image:

```bash
nix build
```

## How It Works

1. **Credentials File**: The `wifi-credentials.json` file contains your WiFi SSID and PSK in JSON format.
2. **Derivation**: The Nix derivation reads the credentials file and generates a NetworkManager connection profile.
3. **Module**: The NixOS module integrates the derivation with the system configuration and deploys the connection profile.
4. **Autoconnect**: NetworkManager automatically connects to the configured WiFi network when in range.

## Security Considerations

- The `wifi-credentials.json` file is excluded from version control via `.gitignore`
- The generated NetworkManager connection profile has restrictive permissions (600, root:root)
- Credentials are only accessible to the root user
- The connection profile is stored in `/etc/NetworkManager/system-connections/`

## Troubleshooting

### WiFi Not Connecting

1. Verify the credentials file exists and has correct permissions:
   ```bash
   ls -la wifi-credentials.json
   ```

2. Check the NetworkManager service status:
   ```bash
   systemctl status NetworkManager
   ```

3. View NetworkManager logs:
   ```bash
   journalctl -u NetworkManager -f
   ```

4. Check if the connection profile was created:
   ```bash
   ls -la /etc/NetworkManager/system-connections/
   ```

### Credentials File Not Found

If you see a warning about the credentials file not being found:
1. Ensure `wifi-credentials.json` exists in the project root
2. Verify the path in `user-config.nix` is correct
3. Check that the file has proper read permissions

### NetworkManager Conflicts

The system disables `wpa_supplicant` to avoid conflicts with NetworkManager. If you have other WiFi management tools, ensure they don't interfere with NetworkManager.

## Advanced Configuration

### Custom Credentials File Path

To use a different path for the credentials file, modify `user-config.nix`:

```nix
network = {
  wifiCredentials = {
    enable = true;
    credentialsFile = /path/to/your/custom-credentials.json;
  };
};
```

### Multiple Networks (Future Enhancement)

The current implementation supports a single WiFi network. For multiple networks, you would need to:
1. Modify the credentials file format to support an array of networks
2. Update the derivation to generate multiple connection profiles
3. Add priority settings to the NetworkManager profiles

## File Permissions

The system ensures proper file permissions:
- Credentials file: Should be readable by the user (644)
- Generated connection profile: Restricted to root (600, root:root)
- NetworkManager system connections directory: Restricted to root (700, root:root)

## Integration with Existing Configuration

The WiFi credentials system integrates seamlessly with the existing networking configuration:
- NetworkManager is enabled by default
- DNS resolution is handled by systemd-resolved
- Firewall settings are preserved
- DHCP configuration is maintained

## Frequently Asked Questions

### Q: Would WiFi credentials be ported during the build-final-image.sh process?

**A:** Yes, the WiFi credentials are fully integrated with the build-final-image.sh process. When you run the build script:

1. **Automatic Detection**: The script automatically checks for the presence of `wifi-credentials.json` in the project root
2. **Validation**: If the credentials file exists, the script validates its JSON format and displays the configured WiFi network name (SSID) and security type
3. **Integration**: The credentials are processed by the Nix derivation and embedded into the final NixOS image
4. **Build-time Feedback**: The script provides clear feedback about whether WiFi autoconnect will be included in the built image

**Build Process Integration:**
- If `wifi-credentials.json` exists: The WiFi configuration is baked into the final image, and the script shows "✓ WiFi credentials file found" with network details
- If `wifi-credentials.json` doesn't exist: The script shows a warning with instructions on how to enable WiFi autoconnect, but continues the build without WiFi configuration
- Invalid JSON: The script exits with an error if the credentials file contains invalid JSON

This means you don't need to manually copy credentials after building - they're included directly in the shimboot image if present at build time.

### Q: Would the example continue to take precedence if config is modified?

**A:** No, the example file (`wifi-credentials.json.example`) never takes precedence. The system specifically looks for `wifi-credentials.json` in the path specified in `user-config.nix`. Here's how it works:

1. The system checks for the actual credentials file path (default: `./wifi-credentials.json`)
2. If the actual file exists, it uses that configuration
3. If the actual file doesn't exist, it shows a warning but continues the build
4. The example file is purely for reference and is never used unless you copy it to create the actual credentials file

This design ensures that your custom configurations always take precedence and the example file serves only as a template.

### Q: Would connection attempts be logged in journald for debugging?

**A:** Yes, NetworkManager logs all connection attempts and detailed information in journald. You can view WiFi-related logs with:

```bash
# View NetworkManager logs in real-time
journalctl -u NetworkManager -f

# View all WiFi-related logs
journalctl -g "wifi" -f

# View NetworkManager logs with extra verbosity
journalctl -u NetworkManager -o verbose -f

# Filter for connection attempts
journalctl -u NetworkManager -g "connection\|connect\|wifi" -f
```

The logs will include:
- Connection attempt timestamps
- Authentication success/failure
- Signal strength and quality
- DHCP configuration
- IP address assignment
- Disconnection events
- Network scanning results

For debugging WiFi connection issues, you can also use:

```bash
# Check NetworkManager status
nmcli general status

# List available WiFi networks
nmcli dev wifi list

# Check connection details
nmcli connection show wifi-autoconnect

# Enable debug logging (temporary)
nmcli general logging level DEBUG
```

## Troubleshooting

### WiFi Not Connecting

1. Verify the credentials file exists and has correct permissions:
   ```bash
   ls -la wifi-credentials.json
   ```

2. Check the NetworkManager service status:
   ```bash
   systemctl status NetworkManager
   ```

3. View NetworkManager logs:
   ```bash
   journalctl -u NetworkManager -f
   ```

4. Check if the connection profile was created:
   ```bash
   ls -la /etc/NetworkManager/system-connections/
   ```

### Credentials File Not Found

If you see a warning about the credentials file not being found:
1. Ensure `wifi-credentials.json` exists in the project root
2. Verify the path in `user-config.nix` is correct
3. Check that the file has proper read permissions

### NetworkManager Conflicts

The system disables `wpa_supplicant` to avoid conflicts with NetworkManager. If you have other WiFi management tools, ensure they don't interfere with NetworkManager.