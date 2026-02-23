#!/usr/bin/env bash

# Setup NixOS Script
#
# Purpose: Interactive post-install setup wizard for NixOS shimboot
# Dependencies: nmcli, git, expand_rootfs, setup_nixos_config, nixos-rebuild
# Related: setup-helpers.nix, networking.nix
#
# This script:
# - Provides interactive post-install setup wizard
# - Handles Wi-Fi, filesystem, and configuration setup
# - Automates system initialization and rebuild processes

set -Eeuo pipefail

# Configuration
USERNAME="${USER}"
CONFIG_DIR="/home/${USERNAME}/nixos-config"
LOG_FILE="/tmp/setup_nixos.log"
BACKUP_DIR="/tmp/setup_nixos_backup_$(date +%Y%m%d_%H%M%S)"

# Parse command line arguments
SKIP_WIFI=false
SKIP_EXPAND=false
SKIP_CONFIG=false
SKIP_REBUILD=false
AUTO_MODE=false
DEBUG=false
HELP=false

while [[ $# -gt 0 ]]; do
	case "$1" in
	--skip-wifi)
		SKIP_WIFI=true
		shift
		;;
	--skip-expand)
		SKIP_EXPAND=true
		shift
		;;
	--skip-config)
		SKIP_CONFIG=true
		shift
		;;
	--skip-rebuild)
		SKIP_REBUILD=true
		shift
		;;
	--auto)
		AUTO_MODE=true
		shift
		;;
	--debug)
		DEBUG=true
		shift
		;;
	--help | -h)
		HELP=true
		shift
		;;
	*)
		echo "Unknown option: $1"
		shift
		;;
	esac
done

# Help message
if [[ "$HELP" == "true" ]]; then
	echo "NixOS Shimboot Setup Script"
	echo ""
	echo "USAGE:"
	echo "    setup_nixos [OPTIONS]"
	echo ""
	echo "OPTIONS:"
	echo "    --skip-wifi      Skip Wi-Fi configuration"
	echo "    --skip-expand    Skip root filesystem expansion"
	echo "    --skip-config    Skip nixos-rebuild configuration"
	echo "    --skip-rebuild   Skip system rebuild"
	echo "    --auto           Run in automatic mode with sensible defaults"
	echo "    --debug          Enable debug output"
	echo "    --help, -h       Show this help message"
	echo ""
	echo "EXAMPLES:"
	echo "    setup_nixos                    # Interactive mode with all steps"
	echo "    setup_nixos --auto             # Automatic mode"
	echo "    setup_nixos --skip-wifi        # Skip Wi-Fi setup"
	echo "    setup_nixos --debug            # Enable debug logging"
	echo ""
	exit 0
fi

# Initialize logging
# Note: To capture output with tee, run: setup_nixos 2>&1 | tee /tmp/setup_nixos.log

# Failsafe: Create backup directory
mkdir -p "$BACKUP_DIR"

# Styling
SN_BOLD='\033[1m'
SN_GREEN='\033[1;32m'
SN_YELLOW='\033[1;33m'
SN_RED='\033[1;31m'
SN_BLUE='\033[1;34m'
SN_CYAN='\033[1;36m'
SN_NC='\033[0m'

# Utility functions
prompt_yes_no() {
	local question="$1"
	local default="${2:-Y}"
	local prompt="[Y/n]"
	if [[ "$default" == "n" ]]; then
		prompt="[y/N]"
	fi

	# In auto mode, use defaults
	if [[ "$AUTO_MODE" == "true" ]]; then
		echo "${question} (auto: ${default})"
		if [[ "${default,,}" =~ ^y(es)?$ ]]; then
			return 0
		else
			return 1
		fi
	fi

	read -r -p "${question} ${prompt} " reply
	reply=$(echo "$reply" | tr '[:upper:]' '[:lower:]' | xargs)

	case "$reply" in
	y | yes)
		return 0
		;;
	n | no)
		return 1
		;;
	*)
		if [[ "$default" == "n" ]]; then
			return 1
		else
			return 0
		fi
		;;
	esac
}

failsafe() {
	local operation="$1"
	shift
	local cmd=("$@")

	echo -e "${SN_YELLOW} Running failsafe for: ${operation} ${SN_NC}"

	if "${cmd[@]}"; then
		echo -e "${SN_GREEN} ✓ Failsafe passed: ${operation} ${SN_NC}"
		return 0
	else
		echo -e "${SN_RED} ✗ Failsafe failed: ${operation} ${SN_NC}"
		echo -e "${SN_YELLOW} Creating backup before continuing... ${SN_NC}"

		# Backup critical files
		[[ -f /etc/nixos/configuration.nix ]] && cp /etc/nixos/configuration.nix "${BACKUP_DIR}/"
		[[ -f /etc/nixos/flake.nix ]] && cp /etc/nixos/flake.nix "${BACKUP_DIR}/"
		[[ -d "${CONFIG_DIR}" ]] && cp -r "${CONFIG_DIR}" "${BACKUP_DIR}/" 2>/dev/null || true

		echo -e "${SN_CYAN} Backup created at: ${BACKUP_DIR} ${SN_NC}"
		return 1
	fi
}

check_prerequisites() {
	echo -e "${SN_BLUE} Checking prerequisites... ${SN_NC}"

	local missing=()

	command -v nmcli >/dev/null 2>&1 || missing+=("networkmanager")
	command -v git >/dev/null 2>&1 || missing+=("git")

	if [[ ${#missing[@]} -gt 0 ]]; then
		echo -e "${SN_YELLOW} Warning: Missing commands: ${missing[*]} ${SN_NC}"
		echo "Some features may not work properly."
	fi

	# Check if running as user (not root)
	if [[ $EUID -eq 0 ]]; then
		echo -e "${SN_YELLOW} Warning: Running as root. Some features may not work correctly. ${SN_NC}"
	fi

	echo -e "${SN_GREEN} ✓ Prerequisite check complete ${SN_NC}"
}

log_step() {
	echo -e "\n${SN_BOLD}${SN_BLUE} === $1 === ${SN_NC}"
}

log_ok() {
	echo -e "${SN_GREEN} ✓ ${SN_NC} $1"
}

log_warn() {
	echo -e "${SN_YELLOW} ⚠ ${SN_NC} $1"
}

log_error() {
	echo -e "${SN_RED} ✗ ${SN_NC} $1"
}

# Run prerequisite checks
check_prerequisites

echo -e "${SN_BOLD} ==================================================="
echo "  NixOS Shimboot Post-Install Setup"
echo -e "=================================================== ${SN_NC} \n"

if [[ "$DEBUG" == "true" ]]; then
	set -x
	echo -e "${SN_CYAN} Debug mode enabled. Log file: ${LOG_FILE} ${SN_NC}"
	echo -e "${SN_CYAN} Backup directory: ${BACKUP_DIR} ${SN_NC}"
	echo
fi

# === Step 1: Wi-Fi ===
if [[ "$SKIP_WIFI" == "false" ]]; then
	log_step "Step 1: Configure Wi-Fi"

	if ! command -v nmcli >/dev/null 2>&1; then
		log_warn "nmcli not found (NetworkManager may not be installed)"
	elif ! nmcli radio wifi 2>/dev/null | grep -q enabled; then
		log_warn "Wi-Fi radio appears to be disabled"
	else
		# Check if already connected to Wi-Fi
		echo "Command: nmcli -t -f active,ssid dev wifi | grep \"^yes:\" | cut -d: -f2-"
		CURRENT_CONNECTION=$(nmcli -t -f active,ssid dev wifi | grep "^yes:" | cut -d: -f2- || true)

		if [[ -n "$CURRENT_CONNECTION" ]]; then
			log_ok "Already connected to Wi-Fi: '${CURRENT_CONNECTION}'"
			echo "Skipping network scan since connection is active."
		else
			echo "Scanning networks..."
			echo "Command: nmcli dev wifi rescan"
			nmcli dev wifi rescan 2>/dev/null || true
			sleep 1

			echo
			echo "Command: nmcli -f SSID,SECURITY,SIGNAL,CHAN dev wifi list | head -15"
			nmcli -f SSID,SECURITY,SIGNAL,CHAN dev wifi list | head -15
			echo

			if prompt_yes_no "Connect to Wi-Fi now?"; then
				read -r -p "SSID: " SSID
				if [[ -n "$SSID" ]]; then
					read -r -s -p "Password: " PSK
					echo

					echo "Command: nmcli dev wifi connect '${SSID}' password '***'"
					if failsafe "Wi-Fi connection" nmcli dev wifi connect "$SSID" password "$PSK"; then
						log_ok "Connected to '${SSID}'"

						# Enable autoconnect
						echo "Command: nmcli -t -f NAME,TYPE connection show | awk -F: -v ssid=\"$SSID\" '\$1 == ssid && \$2 == \"802-11-wireless\" {print \$1; exit}'"
						CONN_NAME=$(nmcli -t -f NAME,TYPE connection show |
							awk -F: -v ssid="$SSID" '$1 == ssid && $2 == "802-11-wireless" {print $1; exit}')
						if [[ -n "$CONN_NAME" ]]; then
							echo "Command: nmcli connection modify \"${CONN_NAME}\" connection.autoconnect yes"
							nmcli connection modify "$CONN_NAME" connection.autoconnect yes 2>/dev/null || true
							log_ok "Enabled autoconnect for '${SSID}'"
						fi
					else
						log_error "Failed to connect (check password/signal)"
					fi
				fi
			fi
		fi
	fi
else
	log_step "Step 1: Configure Wi-Fi (Skipped)"
	echo "Wi-Fi configuration skipped as requested"
fi

# === Step 2: Expand rootfs ===
if [[ "$SKIP_EXPAND" == "false" ]]; then
	log_step "Step 2: Expand Root Filesystem"

	echo "Current disk usage:"
	echo "Command: df -h / | tail -1"
	df -h / | tail -1
	echo

	if prompt_yes_no "Expand root partition to full USB capacity?"; then
		if command -v expand_rootfs >/dev/null 2>&1; then
			echo "Command: sudo expand_rootfs"
			if failsafe "Root filesystem expansion" sudo expand_rootfs; then
				log_ok "Root filesystem expanded"
				echo
				echo "New disk usage:"
				echo "Command: df -h / | tail -1"
				df -h / | tail -1
			else
				log_error "Expansion failed (see errors above)"
			fi
		else
			log_error "expand_rootfs command not found"
		fi
	else
		echo "Skipping expansion (you can run 'sudo expand_rootfs' later)"
	fi
else
	log_step "Step 2: Expand Root Filesystem (Skipped)"
	echo "Root filesystem expansion skipped as requested"
fi

# === Step 3: Verify config ===
log_step "Step 3: Verify NixOS Configuration"

if [[ -d "${CONFIG_DIR}/.git" ]]; then
	log_ok "nixos-config present at ${CONFIG_DIR}"

	# Show build info
	if [[ -f "${CONFIG_DIR}/.shimboot_branch" ]]; then
		echo
		cat "${CONFIG_DIR}/.shimboot_branch"
	fi

	cd "$CONFIG_DIR"
	echo "Command: git rev-parse --abbrev-ref HEAD"
	CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "detached")
	echo "Command: git rev-parse --short HEAD"
	CURRENT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
	echo
	echo "Current: ${CURRENT_BRANCH} @ ${CURRENT_COMMIT}"

	if prompt_yes_no "Update from git remote?" "n"; then
		echo "Command: git fetch origin"
		if failsafe "Git fetch" git fetch origin; then
			log_ok "Fetched updates"

			read -r -p "Switch to branch (Enter to stay on ${CURRENT_BRANCH}): " NEW_BRANCH
			if [[ -n "$NEW_BRANCH" ]] && [[ "$NEW_BRANCH" != "$CURRENT_BRANCH" ]]; then
				echo "Command: git checkout '${NEW_BRANCH}' || git checkout -B '${NEW_BRANCH}' 'origin/${NEW_BRANCH}'"
				if failsafe "Git checkout" bash -c "git checkout '$NEW_BRANCH' || git checkout -B '$NEW_BRANCH' 'origin/$NEW_BRANCH'"; then
					log_ok "Switched to ${NEW_BRANCH}"
				else
					log_error "Branch '${NEW_BRANCH}' not found"
				fi
			elif prompt_yes_no "Pull latest commits on ${CURRENT_BRANCH}?" "Y"; then
				echo "Command: git pull"
				failsafe "Git pull" git pull || log_warn "Pull failed (check for conflicts)"
			fi
		else
			log_error "Fetch failed (check network)"
		fi
	fi
else
	log_warn "nixos-config not found (should be cloned by assemble-final.sh)"
	echo "Expected location: ${CONFIG_DIR}"
	echo "This repository contains the NixOS configuration for shimboot."
fi

# === Step 4: Setup /etc/nixos ===
if [[ "$SKIP_CONFIG" == "false" ]]; then
	log_step "Step 4: Configure nixos-rebuild"

	if prompt_yes_no "Run setup_nixos_config?" "Y"; then
		if command -v setup_nixos_config >/dev/null 2>&1; then
			echo "Command: sudo setup_nixos_config"
			failsafe "Setup nixos config" sudo setup_nixos_config
		else
			log_error "setup_nixos_config command not found"
		fi
	fi
else
	log_step "Step 4: Configure nixos-rebuild (Skipped)"
	echo "nixos-rebuild configuration skipped as requested"
fi

# === Step 5: Rebuild ===
if [[ "$SKIP_REBUILD" == "false" ]]; then
	log_step "Step 5: System Rebuild (Optional)"

	if [[ ! -d "${CONFIG_DIR}" ]]; then
		log_warn "Cannot rebuild without nixos-config"
	elif prompt_yes_no "Run nixos-rebuild switch now?" "n"; then
		cd "$CONFIG_DIR"

		# Available configurations (dynamic detection)
		DEFAULT_HOST="${HOSTNAME:-$(hostname)}"
		CONFIGS=$(nix flake show --json 2>/dev/null | jq -r '.nixosConfigurations | keys[]' 2>/dev/null || true)
		if [[ -z "$CONFIGS" ]]; then
			CONFIGS="${DEFAULT_HOST}-minimal
${DEFAULT_HOST}
nixos-shimboot
raw-efi-system"
		fi

		echo
		echo "Available:"
		echo "Command: echo \"\$CONFIGS\" | nl -w2 -s') '"
		echo "$CONFIGS" | nl -w2 -s') '
		echo "Default: ${DEFAULT_HOST}"
		echo "Note: 'minimal' variant uses only base modules (no desktop environment)"
		echo

		# Handle Ctrl+C / SIGINT cleanly
		# shellcheck disable=SC2329 # Function is invoked via trap
		cleanup() {
			echo
			echo -e "\n\033[1;33m Aborted by user (Ctrl+C).\033[0m"
			exit 130
		}
		trap cleanup INT

		# Numerical selection instead of name input
		CONFIG_COUNT=$(echo "$CONFIGS" | wc -l)
		echo "Select configuration to build (1-${CONFIG_COUNT}):"
		echo "(press Enter for default: ${DEFAULT_HOST})"

		# Read user input safely
		if ! read -r SELECTION; then
			echo
			echo -e "${SN_YELLOW} Input interrupted or cancelled. ${SN_NC}"
			exit 130
		fi

		if [[ -z "$SELECTION" ]]; then
			TARGET="$DEFAULT_HOST"
		else
			echo "Command: echo \"\$CONFIGS\" | sed -n \"${SELECTION} p\""
			TARGET=$(echo "$CONFIGS" | sed -n "${SELECTION} p")
		fi

		echo
		echo "Building configuration: ${TARGET}"
		echo

		# NOTE: Validation skipped — configurations are listed explicitly above.
		# Supports targets like 'nixos-user' without needing 'nixosConfigurations.' prefix.

		export NIX_CONFIG="accept-flake-config = true"

		# Check kernel version for sandbox compatibility
		echo "Command: uname -r"
		KVER=$(uname -r)
		NIX_REBUILD_ARGS=(switch --flake ".#${TARGET}" --option accept-flake-config true)

		if [[ "$KVER" =~ ^([0-9]+)\.([0-9]+) ]]; then
			MAJOR="${BASH_REMATCH[1]}"
			MINOR="${BASH_REMATCH[2]}"
			if [[ "$MAJOR" -lt 5 ]] || { [[ "$MAJOR" -eq 5 ]] && [[ "$MINOR" -lt 6 ]]; }; then
				echo "⚠️  Kernel ${KVER} detected (< 5.6). Disabling sandbox for rebuild."
				NIX_REBUILD_ARGS+=(--option sandbox false)
			fi
		fi

		echo "Command: sudo NIX_CONFIG='${NIX_CONFIG}' nixos-rebuild ${NIX_REBUILD_ARGS[*]}"
		if failsafe "NixOS rebuild" sudo NIX_CONFIG="$NIX_CONFIG" nixos-rebuild "${NIX_REBUILD_ARGS[@]}"; then
			log_ok "Rebuild successful!"
			echo
			echo "System is now running the new configuration."
		else
			log_error "Rebuild failed"
			echo
			echo "Common issues:"
			echo "  • Configuration '${TARGET}' doesn't exist in flake"
			echo "  • Syntax error in .nix files"
			echo "  • Network issues during fetch"
			echo
			echo "To retry:"
			echo "  cd ${CONFIG_DIR}"
			echo "  sudo nixos-rebuild switch --flake .#${TARGET}"
		fi

		# Reset trap
		trap - INT
	fi
else
	log_step "Step 5: System Rebuild (Skipped)"
	echo "System rebuild skipped as requested"
fi

# === Summary ===
echo
log_step "Setup Complete"

# Display fish greeting if available
if command -v fish >/dev/null 2>&1; then
	echo "Command: fish -c \"source ${CONFIG_DIR}/shimboot_config/base_configuration/system_modules/fish_functions/fish-greeting.fish; fish_greeting\""
	fish -c "source ${CONFIG_DIR}/shimboot_config/base_configuration/system_modules/fish_functions/fish-greeting.fish; fish_greeting" 2>/dev/null || true
else
	if command -v fastfetch >/dev/null 2>&1; then
		echo "Command: fastfetch"
		fastfetch
	elif command -v neofetch >/dev/null 2>&1; then
		echo "Command: neofetch"
		neofetch
	else
		echo "System:   $(uname -s) $(uname -r)"
		echo "Hostname: $(hostname)"
		echo "User:     ${USERNAME}"
	fi
fi

exit 0
