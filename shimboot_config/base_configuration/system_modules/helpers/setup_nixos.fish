#!/usr/bin/env fish

# Setup NixOS Function
#
# Purpose: Interactive post-install setup wizard for NixOS shimboot
# Dependencies: nmcli, git, expand_rootfs, setup_nixos_config, nixos-rebuild
# Related: setup-helpers.nix, networking.nix
#
# This function:
# - Provides interactive post-install setup wizard
# - Handles Wi-Fi, filesystem, and configuration setup
# - Automates system initialization and rebuild processes

function setup_nixos
    set -euo pipefail

    # Configuration
    set -l USERNAME "$USER"
    set -l CONFIG_DIR "/home/$USERNAME/nixos-config"
    set -l LOG_FILE "/tmp/setup_nixos.log"
    set -l BACKUP_DIR "/tmp/setup_nixos_backup_"(date +%Y%m%d_%H%M%S)

    # Parse command line arguments
    set -l SKIP_WIFI false
    set -l SKIP_EXPAND false
    set -l SKIP_CONFIG false
    set -l SKIP_REBUILD false
    set -l AUTO_MODE false
    set -l CONFIG_NAME ""
    set -l DEBUG false
    set -l HELP false

    argparse 'skip-wifi' 'skip-expand' 'skip-config' 'skip-rebuild' 'auto' 'config=' 'debug' 'help' 'h' -- $argv

    if set -q _flag_skip_wifi
        set SKIP_WIFI true
    end
    if set -q _flag_skip_expand
        set SKIP_EXPAND true
    end
    if set -q _flag_skip_config
        set SKIP_CONFIG true
    end
    if set -q _flag_skip_rebuild
        set SKIP_REBUILD true
    end
    if set -q _flag_auto
        set AUTO_MODE true
    end
    if set -q _flag_config
        set CONFIG_NAME "$_flag_config"
    end
    if set -q _flag_debug
        set DEBUG true
        set -x
    end
    if set -q _flag_help; or set -q _flag_h
        set HELP true
    end

    # Help message
    if test "$HELP" = true
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
        echo "    --config <name>  Specify which configuration to use for rebuild"
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
    end

    # Initialize logging
    exec > >(tee -a "$LOG_FILE")
    exec 2>&1

    # Failsafe: Create backup directory
    mkdir -p "$BACKUP_DIR"

    # Styling
    set -l BOLD '\033[1m'
    set -l GREEN '\033[1;32m'
    set -l YELLOW '\033[1;33m'
    set -l RED '\033[1;31m'
    set -l BLUE '\033[1;34m'
    set -l CYAN '\033[1;36m'
    set -l NC '\033[0m'

    # Utility functions
    function prompt_yes_no
        set -l question "$argv[1]"
        set -l default (set -q argv[2]; and echo "$argv[2]"; or echo "Y")
        set -l prompt "[Y/n]"
        if test "$default" = "n"
            set prompt "[y/N]"
        end

        # In auto mode, use defaults
        if test "$AUTO_MODE" = true
            echo "$question (auto: $default)"
            if string match -qi "y|yes" "$default"
                return 0
            else
                return 1
            end
        end

        read -r -P "$question $prompt " reply
        set reply (string lower (echo "$reply" | string trim))

        switch "$reply"
            case "y" "yes"
                return 0
            case "n" "no"
                return 1
            case '*'
                if test "$default" = "n"
                    return 1
                else
                    return 0
                end
        end
    end

    function failsafe
        set -l operation "$argv[1]"
        set -l command "$argv[2..]"

        echo -e "$YELLOW Running failsafe for: $operation $NC"

        if eval "$command"
            echo -e "$GREEN ✓ Failsafe passed: $operation $NC"
            return 0
        else
            echo -e "$RED ✗ Failsafe failed: $operation $NC"
            echo -e "$YELLOW Creating backup before continuing... $NC"

            # Backup critical files
            test -f /etc/nixos/configuration.nix; and cp /etc/nixos/configuration.nix "$BACKUP_DIR/"
            test -f /etc/nixos/flake.nix; and cp /etc/nixos/flake.nix "$BACKUP_DIR/"
            test -d "$CONFIG_DIR"; and cp -r "$CONFIG_DIR" "$BACKUP_DIR/" 2>/dev/null; or true

            echo -e "$CYAN Backup created at: $BACKUP_DIR $NC"
            return 1
        end
    end

    function check_prerequisites
        echo -e "$BLUE Checking prerequisites... $NC"

        set -l missing

        command -v nmcli >/dev/null 2>&1; or set -a missing "networkmanager"
        command -v git >/dev/null 2>&1; or set -a missing "git"

        if test (count $missing) -gt 0
            echo -e "$YELLOW Warning: Missing commands: $missing $NC"
            echo "Some features may not work properly."
        end

        # Check if running as user (not root)
        if test (id -u) -eq 0
            echo -e "$YELLOW Warning: Running as root. Some features may not work correctly. $NC"
        end

        echo -e "$GREEN ✓ Prerequisite check complete $NC"
    end

    function log_step
        echo -e "\n$BOLD$BLUE === $argv[1] === $NC"
    end

    function log_ok
        echo -e "$GREEN ✓ $NC $argv[1]"
    end

    function log_warn
        echo -e "$YELLOW ⚠ $NC $argv[1]"
    end

    function log_error
        echo -e "$RED ✗ $NC $argv[1]"
    end

    # Run prerequisite checks
    check_prerequisites

    echo -e "$BOLD ==================================================="
    echo "  NixOS Shimboot Post-Install Setup"
    echo -e "=================================================== $NC \n"

    if test "$DEBUG" = true
        echo -e "$CYAN Debug mode enabled. Log file: $LOG_FILE $NC"
        echo -e "$CYAN Backup directory: $BACKUP_DIR $NC"
        echo
    end

    # === Step 1: Wi-Fi ===
    if test "$SKIP_WIFI" = false
        log_step "Step 1: Configure Wi-Fi"

        if not command -v nmcli >/dev/null 2>&1
            log_warn "nmcli not found (NetworkManager may not be installed)"
        else if not nmcli radio wifi 2>/dev/null | grep -q enabled
            log_warn "Wi-Fi radio appears to be disabled"
        else
            # Check if already connected to Wi-Fi
            echo "Command: nmcli -t -f active,ssid dev wifi | grep \"^yes:\" | cut -d: -f2-"
            set -l CURRENT_CONNECTION (nmcli -t -f active,ssid dev wifi | grep "^yes:" | cut -d: -f2- || true)

            if test -n "$CURRENT_CONNECTION"
                log_ok "Already connected to Wi-Fi: '$CURRENT_CONNECTION'"
                echo "Skipping network scan since connection is active."
            else
                echo "Scanning networks..."
                echo "Command: nmcli dev wifi rescan"
                nmcli dev wifi rescan 2>/dev/null; or true
                sleep 1

                echo
                echo "Command: nmcli -f SSID,SECURITY,SIGNAL,CHAN dev wifi list | head -15"
                nmcli -f SSID,SECURITY,SIGNAL,CHAN dev wifi list | head -15
                echo

                if prompt_yes_no "Connect to Wi-Fi now?"
                    read -r -P "SSID: " SSID
                    if test -n "$SSID"
                        read -r -s -P "Password: " PSK
                        echo

                        echo "Command: nmcli dev wifi connect '$SSID' password '***'"
                        if failsafe "Wi-Fi connection" "nmcli dev wifi connect '$SSID' password '$PSK'"
                            log_ok "Connected to '$SSID'"

                            # Enable autoconnect
                            echo "Command: nmcli -t -f NAME,TYPE connection show | awk -F: -v ssid=\"$SSID\" '\$1 == ssid && \$2 == \"802-11-wireless\" {print \$1; exit}'"
                            set -l CONN_NAME (nmcli -t -f NAME,TYPE connection show | \
                                         awk -F: -v ssid="$SSID" '$1 == ssid && $2 == "802-11-wireless" {print $1; exit}')
                            if test -n "$CONN_NAME"
                                echo "Command: nmcli connection modify \"$CONN_NAME\" connection.autoconnect yes"
                                nmcli connection modify "$CONN_NAME" connection.autoconnect yes 2>/dev/null; or true
                                log_ok "Enabled autoconnect for '$SSID'"
                            end
                        else
                            log_error "Failed to connect (check password/signal)"
                        end
                    end
                end
            end
        end
    else
        log_step "Step 1: Configure Wi-Fi (Skipped)"
        echo "Wi-Fi configuration skipped as requested"
    end

    # === Step 2: Expand rootfs ===
    if test "$SKIP_EXPAND" = false
        log_step "Step 2: Expand Root Filesystem"

        echo "Current disk usage:"
        echo "Command: df -h / | tail -1"
        df -h / | tail -1
        echo

        if prompt_yes_no "Expand root partition to full USB capacity?"
            if command -v expand_rootfs >/dev/null 2>&1
                echo "Command: sudo expand_rootfs"
                if failsafe "Root filesystem expansion" "sudo expand_rootfs"
                    log_ok "Root filesystem expanded"
                    echo
                    echo "New disk usage:"
                    echo "Command: df -h / | tail -1"
                    df -h / | tail -1
                else
                    log_error "Expansion failed (see errors above)"
                end
            else
                log_error "expand_rootfs command not found"
            end
        else
            echo "Skipping expansion (you can run 'sudo expand_rootfs' later)"
        end
    else
        log_step "Step 2: Expand Root Filesystem (Skipped)"
        echo "Root filesystem expansion skipped as requested"
    end

    # === Step 3: Verify config ===
    log_step "Step 3: Verify NixOS Configuration"

    if test -d "$CONFIG_DIR/.git"
        log_ok "nixos-config present at $CONFIG_DIR"

        # Show build info
        if test -f "$CONFIG_DIR/.shimboot_branch"
            echo
            cat "$CONFIG_DIR/.shimboot_branch"
        end

        cd "$CONFIG_DIR"
        echo "Command: git rev-parse --abbrev-ref HEAD"
        set -l CURRENT_BRANCH (git rev-parse --abbrev-ref HEAD 2>/dev/null; or echo "detached")
        echo "Command: git rev-parse --short HEAD"
        set -l CURRENT_COMMIT (git rev-parse --short HEAD 2>/dev/null; or echo "unknown")
        echo
        echo "Current: $CURRENT_BRANCH @ $CURRENT_COMMIT"

        if prompt_yes_no "Update from git remote?" n
            echo "Command: git fetch origin"
            if failsafe "Git fetch" "git fetch origin"
                log_ok "Fetched updates"

                read -r -P "Switch to branch (Enter to stay on $CURRENT_BRANCH): " NEW_BRANCH
                if test -n "$NEW_BRANCH"; and test "$NEW_BRANCH" != "$CURRENT_BRANCH"
                    echo "Command: git checkout '$NEW_BRANCH' || git checkout -B '$NEW_BRANCH' 'origin/$NEW_BRANCH'"
                    if failsafe "Git checkout" "git checkout '$NEW_BRANCH' || git checkout -B '$NEW_BRANCH' 'origin/$NEW_BRANCH'"
                        log_ok "Switched to $NEW_BRANCH"
                    else
                        log_error "Branch '$NEW_BRANCH' not found"
                    end
                else if prompt_yes_no "Pull latest commits on $CURRENT_BRANCH?" Y
                    echo "Command: git pull"
                    failsafe "Git pull" "git pull"; or log_warn "Pull failed (check for conflicts)"
                end
            else
                log_error "Fetch failed (check network)"
            end
        end
    else
        log_warn "nixos-config not found (should be cloned by assemble-final.sh)"
        echo "Expected location: $CONFIG_DIR"
        echo "This repository contains the NixOS configuration for shimboot."
    end

    # === Step 4: Setup /etc/nixos ===
    if test "$SKIP_CONFIG" = false
        log_step "Step 4: Configure nixos-rebuild"

        if prompt_yes_no "Run setup_nixos_config?" Y
            if command -v setup_nixos_config >/dev/null 2>&1
                echo "Command: sudo setup_nixos_config"
                failsafe "Setup nixos config" "sudo setup_nixos_config"
            else
                log_error "setup_nixos_config command not found"
            end
        end
    else
        log_step "Step 4: Configure nixos-rebuild (Skipped)"
        echo "nixos-rebuild configuration skipped as requested"
    end

    # === Step 5: Rebuild ===
    if test "$SKIP_REBUILD" = false
        log_step "Step 5: System Rebuild (Optional)"

        if not test -d "$CONFIG_DIR"
            log_warn "Cannot rebuild without nixos-config"
        else if prompt_yes_no "Run nixos-rebuild switch now?" n
            cd "$CONFIG_DIR"

            # Available configurations (no flake evaluation needed)
            set -l DEFAULT_HOST (set -q HOSTNAME; and echo "$HOSTNAME"; or hostname)
            set -l CONFIGS "$DEFAULT_HOST-minimal
$DEFAULT_HOST
nixos-shimboot
raw-efi-system"

            echo
            echo "Available:"
            echo "Command: echo \"$CONFIGS\" | nl -w2 -s') '"
            echo "$CONFIGS" | nl -w2 -s') '
            echo "Default: $DEFAULT_HOST"
            echo "Note: 'minimal' variant uses only base modules (no desktop environment)"
            echo

            # Handle Ctrl+C / SIGINT cleanly
            function handle_sigint --on-signal INT
                echo
                echo -e "\n\033[1;33m Aborted by user (Ctrl+C).\033[0m"
                exit 130
            end

            # Numerical selection instead of name input
            echo "Select configuration to build (1-"(echo "$CONFIGS" | wc -l)"):"
            echo "(press Enter for default: $DEFAULT_HOST)"

            # Read user input safely
            if not read -r SELECTION
                echo
                echo -e "$YELLOW Input interrupted or cancelled. $NC"
                exit 130
            end

            if test -z "$SELECTION"
                set TARGET "$DEFAULT_HOST"
            else
                echo "Command: echo \"$CONFIGS\" | sed -n \"$SELECTION p\""
                set TARGET (echo "$CONFIGS" | sed -n "$SELECTION p")
            end

            echo
            echo "Building configuration: $TARGET"
            echo

            # NOTE: Validation skipped — configurations are listed explicitly above.
            # Supports targets like 'nixos-user' without needing 'nixosConfigurations.' prefix.

            set -gx NIX_CONFIG "accept-flake-config = true"

            # Check kernel version for sandbox compatibility
            echo "Command: uname -r"
            set -l KVER (uname -r)
            set -l NIX_REBUILD_ARGS "switch --flake .#$TARGET --option accept-flake-config true"

            if string match -qr '^([0-9]+)\.([0-9]+)' "$KVER"
                set -l MAJOR (string split '.' "$KVER")[1]
                set -l MINOR (string split '.' "$KVER")[2]
                if test "$MAJOR" -lt 5; or (test "$MAJOR" -eq 5; and test "$MINOR" -lt 6)
                    echo "⚠️  Kernel $KVER detected (< 5.6). Disabling sandbox for rebuild."
                    set NIX_REBUILD_ARGS "$NIX_REBUILD_ARGS --option sandbox false"
                end
            end

            echo "Command: sudo NIX_CONFIG='$NIX_CONFIG' nixos-rebuild $NIX_REBUILD_ARGS"
            if failsafe "NixOS rebuild" "sudo NIX_CONFIG='$NIX_CONFIG' nixos-rebuild $NIX_REBUILD_ARGS"
                log_ok "Rebuild successful!"
                echo
                echo "System is now running the new configuration."
            else
                log_error "Rebuild failed"
                echo
                echo "Common issues:"
                echo "  • Configuration '$TARGET' doesn't exist in flake"
                echo "  • Syntax error in .nix files"
                echo "  • Network issues during fetch"
                echo
                echo "To retry:"
                echo "  cd $CONFIG_DIR"
                echo "  sudo nixos-rebuild switch --flake .#$TARGET"
            end
        end
    else
        log_step "Step 5: System Rebuild (Skipped)"
        echo "System rebuild skipped as requested"
    end

    # === Summary ===
    echo
    log_step "Setup Complete"

    # Display fish greeting if available
    if command -v fish >/dev/null 2>&1
        echo "Command: fish -c \"source $CONFIG_DIR/shimboot_config/base_configuration/system_modules/fish_functions/fish-greeting.fish; fish_greeting\""
        fish -c "source $CONFIG_DIR/shimboot_config/base_configuration/system_modules/fish_functions/fish-greeting.fish; fish_greeting" 2>/dev/null; or true
    else
        if command -v fastfetch >/dev/null 2>&1
            echo "Command: fastfetch"
            fastfetch
        else if command -v neofetch >/dev/null 2>&1
            echo "Command: neofetch"
            neofetch
        else
            echo "System:   "(uname -s) (uname -r)
            echo "Hostname: "(hostname)
            echo "User:     $USERNAME"
        end
    end

    exit 0
end
