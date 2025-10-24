{
  config,
  pkgs,
  lib,
  userConfig,
  ...
}: let
  # Extract username at Nix evaluation time
  username = userConfig.user.username;
in {
  environment.systemPackages = with pkgs; [
    (writeShellScriptBin "setup_nixos_config" ''
            set -euo pipefail

            if [ "$EUID" -ne 0 ]; then
              echo "This script must be run as root."
              exit 1
            fi

            USERNAME="${username}"
            NIXOS_CONFIG_PATH="/home/$USERNAME/nixos-config"

            echo "[setup_nixos_config] Configuring /etc/nixos for nixos-rebuild..."
            mkdir -p /etc/nixos

            # Generate hardware config if missing
            if [ ! -f /etc/nixos/hardware-configuration.nix ]; then
              echo "[setup_nixos_config] Generating hardware-configuration.nix..."
              nixos-generate-config --root / --show-hardware-config > /etc/nixos/hardware-configuration.nix
            fi

            # Strategy: use user's custom config if present, otherwise minimal fallback
            if [ -d "$NIXOS_CONFIG_PATH" ] && [ -f "$NIXOS_CONFIG_PATH/flake.nix" ]; then
              echo "[setup_nixos_config] ✓ Found nixos-config at $NIXOS_CONFIG_PATH"

              # Backup existing /etc/nixos files
              for file in configuration.nix flake.nix; do
                if [ -f "/etc/nixos/$file" ] && [ ! -L "/etc/nixos/$file" ]; then
                  echo "[setup_nixos_config] Backing up /etc/nixos/$file → $file.bak"
                  mv "/etc/nixos/$file" "/etc/nixos/$file.bak"
                fi
              done

              # Create symlink to user's flake
              ln -sf "$NIXOS_CONFIG_PATH/flake.nix" /etc/nixos/flake.nix

              HOSTNAME="''${HOSTNAME:-$(hostname)}"
              echo
              echo "[setup_nixos_config] ✓ Linked to your custom configuration"
              echo
              echo "To rebuild:"
              echo "  cd $NIXOS_CONFIG_PATH"
              echo "  sudo nixos-rebuild switch --flake .#$HOSTNAME"
              echo
              echo "Available configurations:"
              if command -v nix >/dev/null 2>&1; then
                (cd "$NIXOS_CONFIG_PATH" && \
                 nix flake show --json 2>/dev/null | \
                 ${pkgs.jq}/bin/jq -r '.nixosConfigurations | keys[]' 2>/dev/null) || \
                 echo "  (run 'nix flake show' in $NIXOS_CONFIG_PATH to list)"
              fi
            else
              echo "[setup_nixos_config] No custom config found at $NIXOS_CONFIG_PATH"
              echo "[setup_nixos_config] Creating minimal standalone configuration..."

              # Write minimal configuration.nix with proper escaping
              cat > /etc/nixos/configuration.nix <<'EOF'
      { config, pkgs, lib, ... }:
      {
        imports = [ ./hardware-configuration.nix ];

        # Enable Nix flakes
        nix.settings.experimental-features = [ "nix-command" "flakes" ];

        # Binary caches
        nix.settings.substituters = [
          "https://cache.nixos.org"
          "https://shimboot-systemd-nixos.cachix.org"
        ];
        nix.settings.trusted-public-keys = [
          "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
          "shimboot-systemd-nixos.cachix.org-1:vCWmEtJq7hA2UOLN0s3njnGs9/EuX06kD7qOJMo2kAA="
        ];

        # Networking
        networking.hostName = "shimboot";
        networking.networkmanager.enable = true;

        # Services
        services.openssh.enable = true;

        # User account
      EOF
              echo "  users.users.${username} = {" >> /etc/nixos/configuration.nix
              cat >> /etc/nixos/configuration.nix <<'EOF'
          isNormalUser = true;
          extraGroups = [ "wheel" "networkmanager" "video" "audio" ];
      EOF
              echo "    initialPassword = \"${username}\";" >> /etc/nixos/configuration.nix
              cat >> /etc/nixos/configuration.nix <<'EOF'
        };

        # Allow unfree packages (ChromeOS firmware)
        nixpkgs.config.allowUnfree = true;

        # Essential packages
        environment.systemPackages = with pkgs; [
          vim wget git curl htop
          firefox chromium
        ];

        system.stateVersion = "24.11";
      }
      EOF

              # Write minimal flake
              cat > /etc/nixos/flake.nix <<'EOF'
      {
        description = "Shimboot minimal NixOS configuration";

        inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

        outputs = { self, nixpkgs, ... }: {
          nixosConfigurations.shimboot = nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            modules = [ ./configuration.nix ];
          };
        };
      }
      EOF

              echo
              echo "[setup_nixos_config] ✓ Created minimal config at /etc/nixos"
              echo
              echo "To customize: sudo $EDITOR /etc/nixos/configuration.nix"
              echo "To rebuild:   sudo nixos-rebuild switch --flake /etc/nixos#shimboot"
            fi

            echo
            echo "[setup_nixos_config] Done."
    '')

    (writeShellScriptBin "setup_nixos" ''
      set -euo pipefail

      USERNAME="${username}"
      CONFIG_DIR="/home/$USERNAME/nixos-config"

      # Styling
      BOLD='\033[1m'
      GREEN='\033[1;32m'
      YELLOW='\033[1;33m'
      RED='\033[1;31m'
      BLUE='\033[1;34m'
      NC='\033[0m'

      prompt_yes_no() {
        local question="$1"
        local default="''${2:-Y}"
        local prompt="[Y/n]"
        [ "$default" = "n" ] && prompt="[y/N]"

        local reply
        read -r -p "$question $prompt " reply
        reply="$(echo "''${reply:-$default}" | tr '[:upper:]' '[:lower:]')"

        case "$reply" in
          y|yes) return 0 ;;
          n|no)  return 1 ;;
          *) [ "$default" = "n" ] && return 1 || return 0 ;;
        esac
      }

      log_step() {
        echo -e "\n''${BOLD}''${BLUE}=== $1 ===''${NC}"
      }

      log_ok() {
        echo -e "''${GREEN}✓''${NC} $1"
      }

      log_warn() {
        echo -e "''${YELLOW}⚠''${NC} $1"
      }

      log_error() {
        echo -e "''${RED}✗''${NC} $1"
      }

      echo -e "''${BOLD}==================================================="
      echo "  NixOS Shimboot Post-Install Setup"
      echo -e "==================================================''${NC}\n"

      # === Step 1: Wi-Fi ===
      log_step "Step 1: Configure Wi-Fi"

      if ! command -v nmcli >/dev/null 2>&1; then
        log_warn "nmcli not found (NetworkManager may not be installed)"
      elif ! nmcli radio wifi 2>/dev/null | grep -q enabled; then
        log_warn "Wi-Fi radio appears to be disabled"
      else
        echo "Scanning networks..."
        nmcli dev wifi rescan 2>/dev/null || true
        sleep 1

        echo
        nmcli -f SSID,SECURITY,SIGNAL,CHAN dev wifi list | head -15
        echo

        if prompt_yes_no "Connect to Wi-Fi now?"; then
          read -r -p "SSID: " SSID
          if [ -n "$SSID" ]; then
            read -r -s -p "Password: " PSK
            echo

            if nmcli dev wifi connect "$SSID" password "$PSK" 2>/dev/null; then
              log_ok "Connected to '$SSID'"

              # Enable autoconnect
              CONN_NAME="$(nmcli -t -f NAME,TYPE connection show | \
                           awk -F: -v ssid="$SSID" '$1 == ssid && $2 == "802-11-wireless" {print $1; exit}')"
              if [ -n "$CONN_NAME" ]; then
                nmcli connection modify "$CONN_NAME" connection.autoconnect yes 2>/dev/null || true
                log_ok "Enabled autoconnect for '$SSID'"
              fi
            else
              log_error "Failed to connect (check password/signal)"
            fi
          fi
        fi
      fi

      # === Step 2: Expand rootfs ===
      log_step "Step 2: Expand Root Filesystem"

      echo "Current disk usage:"
      df -h / | tail -1
      echo

      if prompt_yes_no "Expand root partition to full USB capacity?"; then
        if command -v expand_rootfs >/dev/null 2>&1; then
          if sudo expand_rootfs; then
            log_ok "Root filesystem expanded"
            echo
            echo "New disk usage:"
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

      # === Step 3: Verify config ===
      log_step "Step 3: Verify NixOS Configuration"

      if [ -d "$CONFIG_DIR/.git" ]; then
        log_ok "nixos-config present at $CONFIG_DIR"

        # Show build info
        if [ -f "$CONFIG_DIR/.shimboot_branch" ]; then
          echo
          cat "$CONFIG_DIR/.shimboot_branch"
        fi

        cd "$CONFIG_DIR"
        CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "detached")"
        CURRENT_COMMIT="$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")"
        echo
        echo "Current: $CURRENT_BRANCH @ $CURRENT_COMMIT"

        if prompt_yes_no "Update from git remote?" n; then
          if git fetch origin 2>/dev/null; then
            log_ok "Fetched updates"

            read -r -p "Switch to branch (Enter to stay on $CURRENT_BRANCH): " NEW_BRANCH
            if [ -n "$NEW_BRANCH" ] && [ "$NEW_BRANCH" != "$CURRENT_BRANCH" ]; then
              if git checkout "$NEW_BRANCH" 2>/dev/null || \
                 git checkout -B "$NEW_BRANCH" "origin/$NEW_BRANCH" 2>/dev/null; then
                log_ok "Switched to $NEW_BRANCH"
              else
                log_error "Branch '$NEW_BRANCH' not found"
              fi
            elif prompt_yes_no "Pull latest commits on $CURRENT_BRANCH?" Y; then
              git pull || log_warn "Pull failed (check for conflicts)"
            fi
          else
            log_error "Fetch failed (check network)"
          fi
        fi
      else
        log_warn "nixos-config not found (unusual for Shimboot build)"
        echo "Expected location: $CONFIG_DIR"
      fi

      # === Step 4: Setup /etc/nixos ===
      log_step "Step 4: Configure nixos-rebuild"

      if prompt_yes_no "Run setup_nixos_config?" Y; then
        if command -v setup_nixos_config >/dev/null 2>&1; then
          sudo setup_nixos_config
        else
          log_error "setup_nixos_config command not found"
        fi
      fi

      # === Step 5: Rebuild ===
      log_step "Step 5: System Rebuild (Optional)"

      if [ ! -d "$CONFIG_DIR" ]; then
        log_warn "Cannot rebuild without nixos-config"
      elif prompt_yes_no "Run nixos-rebuild switch now?" n; then
        cd "$CONFIG_DIR"

        # Detect available configs
        echo "Scanning for configurations..."
        CONFIGS="$(nix flake show --json 2>/dev/null | \
                   ${pkgs.jq}/bin/jq -r '.nixosConfigurations | keys[]' 2>/dev/null || \
                   echo "shimboot")"

        if [ -n "$CONFIGS" ]; then
          echo
          echo "Available:"
          echo "$CONFIGS" | nl -w2 -s') '
          echo
        fi

        DEFAULT_HOST="''${HOSTNAME:-$(hostname)}"
        read -r -p "Configuration name [$DEFAULT_HOST]: " TARGET
        TARGET="''${TARGET:-$DEFAULT_HOST}"

        echo
        echo "Building: .#$TARGET"
        echo "This may take several minutes..."
        echo

        export NIX_CONFIG="accept-flake-config = true"

        if sudo NIX_CONFIG="$NIX_CONFIG" nixos-rebuild switch \
          --flake ".#$TARGET" \
          --option sandbox false \
          --option accept-flake-config true; then
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
        fi
      fi

      # === Summary ===
      echo
      log_step "Setup Complete"

      if command -v fastfetch >/dev/null 2>&1; then
        fastfetch
      elif command -v neofetch >/dev/null 2>&1; then
        neofetch
      else
        echo "System:   $(uname -s) $(uname -r)"
        echo "Hostname: $(hostname)"
        echo "User:     $USERNAME"
      fi

      echo
      echo -e "''${BOLD}Next Steps:''${NC}"
      echo "  • Customize:  edit $CONFIG_DIR"
      echo "  • Rebuild:    cd $CONFIG_DIR && sudo nixos-rebuild switch --flake .#\$(hostname)"
      echo "  • Expand FS:  sudo expand_rootfs"
      echo "  • Network:    nmcli"
      echo

      exit 0
    '')
  ];
}
