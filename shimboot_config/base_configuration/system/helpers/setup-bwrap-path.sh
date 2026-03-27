#!/usr/bin/env bash

# Setup Bwrap PATH Integration
#
# Purpose: Automatically integrate bwrap-wrapper into system PATH
# Dependencies: mkdir, ln
# Related: security.nix, bwrap-wrapper.sh
#
# This script:
# - Creates a wrapper directory that's earlier in PATH
# - Links bwrap-wrapper to intercept all bwrap calls
# - Provides transparent workaround for ChromeOS LSM restrictions
# - Runs automatically on system activation

set -Eeuo pipefail

# Configuration
WRAPPER_DIR="/usr/local/bin/bwrap-wrappers"
BWRAP_WRAPPER="/run/current-system/sw/bin/bwrap-wrapper"
BWRAP_LINK="${WRAPPER_DIR}/bwrap"

# Create wrapper directory
mkdir -p "$WRAPPER_DIR"

# Create symlink to bwrap-wrapper
if [[ -f "$BWRAP_WRAPPER" ]]; then
	ln -sf "$BWRAP_WRAPPER" "$BWRAP_LINK"
	echo "Bwrap wrapper installed at: ${BWRAP_LINK}"
else
	echo "Warning: bwrap-wrapper not found at: ${BWRAP_WRAPPER}"
fi

# Add wrapper directory to PATH via profile.d
cat > /etc/profile.d/bwrap-wrapper.sh << 'EOF'
# Add bwrap wrapper directory to PATH
# This ensures bwrap-wrapper is used instead of system bwrap
export PATH="/usr/local/bin/bwrap-wrappers:${PATH}"
EOF

chmod 644 /etc/profile.d/bwrap-wrapper.sh

echo "Bwrap PATH integration complete"
echo "Wrapper directory: ${WRAPPER_DIR}"
echo "Profile script: /etc/profile.d/bwrap-wrapper.sh"
echo ""
echo "Note: You may need to log out and log back in for PATH changes to take effect"
echo "Or run: source /etc/profile.d/bwrap-wrapper.sh"
