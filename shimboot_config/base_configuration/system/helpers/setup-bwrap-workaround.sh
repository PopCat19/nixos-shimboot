#!/usr/bin/env bash

# Setup Bwrap Workaround Script
#
# Purpose: Configure bwrap workarounds for ChromeOS LSM restrictions
# Dependencies: bwrap, mkdir, ln
# Related: security.nix, fix-steam-bwrap.sh, bwrap-lsm-workaround.sh
#
# This script:
# - Sets up bwrap cache directory with proper permissions
# - Creates symlinks for applications that need bwrap workarounds
# - Provides instructions for manual bwrap configuration
# - Handles common applications like Steam, AppImages, and Nix packages

set -Eeuo pipefail

# Colors & Logging
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
NC='\033[0m'

echo -e "${BLUE}[INFO]${NC} Setting up bwrap workarounds for ChromeOS LSM..."

# Configuration
BWRAP_CACHE_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/bwrap-cache"
SYSTEM_BWRAP_SAFE="/run/wrappers/bin/bwrap-safe"
SYSTEM_BWRAP="/run/wrappers/bin/bwrap"

# Create bwrap cache directory
echo -e "${BLUE}[STEP]${NC} Creating bwrap cache directory..."
mkdir -p "$BWRAP_CACHE_DIR"
chmod 700 "$BWRAP_CACHE_DIR"
echo -e "${GREEN}[OK]${NC} Cache directory created at: ${BWRAP_CACHE_DIR}"

# Check for bwrap-safe wrapper
if [[ -f "$SYSTEM_BWRAP_SAFE" ]]; then
	echo -e "${GREEN}[OK]${NC} bwrap-safe wrapper found at: ${SYSTEM_BWRAP_SAFE}"
	BWRAP_TO_USE="$SYSTEM_BWRAP_SAFE"
elif [[ -f "$SYSTEM_BWRAP" ]]; then
	echo -e "${YELLOW}[WARN]${NC} bwrap-safe not found, using regular bwrap"
	BWRAP_TO_USE="$SYSTEM_BWRAP"
else
	echo -e "${RED}[ERROR]${NC} No bwrap wrapper found"
	exit 1
fi

# Test bwrap functionality
echo -e "${BLUE}[STEP]${NC} Testing bwrap functionality..."
if $BWRAP_TO_USE --ro-bind / / --dev /dev --proc /proc echo "bwrap test successful" 2>/dev/null; then
	echo -e "${GREEN}[OK]${NC} bwrap is working correctly"
else
	echo -e "${RED}[ERROR]${NC} bwrap test failed"
	exit 1
fi

# Test tmpfs workaround
echo -e "${BLUE}[STEP]${NC} Testing tmpfs workaround..."
if $BWRAP_TO_USE --ro-bind / / --dev /dev --proc /proc --tmpfs /tmp echo "tmpfs workaround test" 2>/dev/null; then
	echo -e "${GREEN}[OK]${NC} tmpfs workaround is working"
else
	echo -e "${YELLOW}[WARN]${NC} tmpfs workaround may not be working (this is expected on some systems)"
fi

# Create wrapper for common applications
echo -e "${BLUE}[STEP]${NC} Creating application wrappers..."

# Create a generic bwrap wrapper script
WRAPPER_DIR="${HOME}/.local/bin"
mkdir -p "$WRAPPER_DIR"

cat > "${WRAPPER_DIR}/bwrap-safe" << 'EOF'
#!/usr/bin/env bash
# Generic bwrap wrapper that uses the system bwrap-safe
exec /run/wrappers/bin/bwrap-safe "$@"
EOF

chmod +x "${WRAPPER_DIR}/bwrap-safe"
echo -e "${GREEN}[OK]${NC} Created wrapper at: ${WRAPPER_DIR}/bwrap-safe"

# Instructions for users
echo ""
echo -e "${CYAN}[INFO]${NC} Bwrap workarounds configured successfully!"
echo ""
echo -e "${BLUE}Usage Instructions:${NC}"
echo ""
echo -e "1. For AppImages and Nix packages:"
echo -e "   ${YELLOW}bwrap-safe --ro-bind / / --dev /dev --proc /proc --tmpfs /tmp ./YourApp.AppImage${NC}"
echo ""
echo -e "2. For Steam (if already patched):"
echo -e "   ${YELLOW}fix-steam-bwrap${NC}"
echo ""
echo -e "3. For manual bwrap usage:"
echo -e "   ${YELLOW}/run/wrappers/bin/bwrap-safe [bwrap arguments]${NC}"
echo ""
echo -e "4. To test bwrap functionality:"
echo -e "   ${YELLOW}bwrap-safe --ro-bind / / --dev /dev --proc /proc echo 'test'${NC}"
echo ""
echo -e "${BLUE}Notes:${NC}"
echo -e "- The bwrap-safe wrapper converts tmpfs mounts to bind mounts"
echo -e "- This works around ChromeOS LSM restrictions on tmpfs"
echo -e "- Cache directory: ${BWRAP_CACHE_DIR}"
echo -e "- System wrapper: ${BWRAP_TO_USE}"
echo ""

exit 0
