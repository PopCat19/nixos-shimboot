#!/usr/bin/env bash
# Test script for WiFi credentials setup

set -euo pipefail

echo "=== WiFi Credentials Setup Test ==="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}[$(date '+%Y-%m-%d %H:%M:%S')] ${message}${NC}"
}

# Test 1: Check if example file exists
print_status $YELLOW "Test 1: Checking if example credentials file exists..."
if [ -f "wifi-credentials.json.example" ]; then
    print_status $GREEN "✓ Example credentials file exists"
else
    print_status $RED "✗ Example credentials file missing"
    exit 1
fi

# Test 2: Check if .gitignore contains wifi-credentials.json
print_status $YELLOW "Test 2: Checking if .gitignore contains wifi-credentials.json..."
if grep -q "wifi-credentials.json" .gitignore; then
    print_status $GREEN "✓ wifi-credentials.json is in .gitignore"
else
    print_status $RED "✗ wifi-credentials.json is not in .gitignore"
    exit 1
fi

# Test 3: Check if derivation file exists
print_status $YELLOW "Test 3: Checking if WiFi credentials derivation exists..."
if [ -f "wifi-credentials-derivation.nix" ]; then
    print_status $GREEN "✓ WiFi credentials derivation file exists"
else
    print_status $RED "✗ WiFi credentials derivation file missing"
    exit 1
fi

# Test 4: Check if module file exists
print_status $YELLOW "Test 4: Checking if WiFi credentials module exists..."
if [ -f "system_modules/wifi-credentials.nix" ]; then
    print_status $GREEN "✓ WiFi credentials module file exists"
else
    print_status $RED "✗ WiFi credentials module file missing"
    exit 1
fi

# Test 5: Check if configuration.nix imports the module
print_status $YELLOW "Test 5: Checking if configuration.nix imports WiFi credentials module..."
if grep -q "wifi-credentials.nix" configuration.nix; then
    print_status $GREEN "✓ configuration.nix imports WiFi credentials module"
else
    print_status $RED "✗ configuration.nix does not import WiFi credentials module"
    exit 1
fi

# Test 6: Check if user-config.nix has WiFi credentials configuration
print_status $YELLOW "Test 6: Checking if user-config.nix has WiFi credentials configuration..."
if grep -q "wifiCredentials" user-config.nix; then
    print_status $GREEN "✓ user-config.nix has WiFi credentials configuration"
else
    print_status $RED "✗ user-config.nix does not have WiFi credentials configuration"
    exit 1
fi

# Test 7: Check if documentation exists
print_status $YELLOW "Test 7: Checking if documentation exists..."
if [ -f "docs/wifi-credentials-setup.md" ]; then
    print_status $GREEN "✓ Documentation exists"
else
    print_status $RED "✗ Documentation missing"
    exit 1
fi

# Test 8: Try to parse example JSON file
print_status $YELLOW "Test 8: Testing JSON parsing of example file..."
if command -v jq &> /dev/null; then
    if jq empty wifi-credentials.json.example 2>/dev/null; then
        print_status $GREEN "✓ Example JSON file is valid"
        
        # Extract values from example
        SSID=$(jq -r '.wifi.ssid' wifi-credentials.json.example)
        PSK=$(jq -r '.wifi.psk' wifi-credentials.json.example)
        SECURITY=$(jq -r '.wifi.security' wifi-credentials.json.example)
        
        print_status $YELLOW "Example configuration:"
        echo "  SSID: $SSID"
        echo "  PSK: $PSK"
        echo "  Security: $SECURITY"
    else
        print_status $RED "✗ Example JSON file is invalid"
        exit 1
    fi
else
    print_status $YELLOW "⚠ jq not available, skipping JSON validation test"
fi

# Test 9: Check if actual credentials file exists (optional)
print_status $YELLOW "Test 9: Checking if actual credentials file exists..."
if [ -f "wifi-credentials.json" ]; then
    print_status $GREEN "✓ Actual credentials file exists"
    
    # Validate actual credentials file if jq is available
    if command -v jq &> /dev/null; then
        if jq empty wifi-credentials.json 2>/dev/null; then
            print_status $GREEN "✓ Actual credentials JSON file is valid"
            
            # Extract values from actual file
            ACTUAL_SSID=$(jq -r '.wifi.ssid' wifi-credentials.json)
            ACTUAL_PSK=$(jq -r '.wifi.psk' wifi-credentials.json)
            ACTUAL_SECURITY=$(jq -r '.wifi.security' wifi-credentials.json)
            
            print_status $YELLOW "Actual configuration:"
            echo "  SSID: $ACTUAL_SSID"
            echo "  PSK: ${ACTUAL_PSK:0:4}****"  # Show only first 4 characters of PSK
            echo "  Security: $ACTUAL_SECURITY"
        else
            print_status $RED "✗ Actual credentials JSON file is invalid"
            exit 1
        fi
    fi
else
    print_status $YELLOW "⚠ Actual credentials file does not exist (this is normal for first-time setup)"
fi

# Test 10: Check Nix syntax
print_status $YELLOW "Test 10: Checking Nix syntax..."
if command -v nix-instantiate &> /dev/null; then
    if nix-instantiate --eval --strict wifi-credentials-derivation.nix 2>/dev/null; then
        print_status $GREEN "✓ WiFi credentials derivation has valid Nix syntax"
    else
        print_status $RED "✗ WiFi credentials derivation has Nix syntax errors"
        exit 1
    fi
    
    if nix-instantiate --eval --strict system_modules/wifi-credentials.nix 2>/dev/null; then
        print_status $GREEN "✓ WiFi credentials module has valid Nix syntax"
    else
        print_status $RED "✗ WiFi credentials module has Nix syntax errors"
        exit 1
    fi
else
    print_status $YELLOW "⚠ nix-instantiate not available, skipping Nix syntax validation"
fi

print_status $GREEN "=== All tests completed successfully! ==="
print_status $GREEN "WiFi credentials setup is ready to use."
print_status $YELLOW ""
print_status $YELLOW "Next steps:"
print_status $YELLOW "1. Copy wifi-credentials.json.example to wifi-credentials.json"
print_status $YELLOW "2. Edit wifi-credentials.json with your WiFi credentials"
print_status $YELLOW "3. Build your NixOS system with: nixos-rebuild switch"
print_status $YELLOW "4. Or build the shimboot image with: nix build"