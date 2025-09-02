{ config, pkgs, lib, userConfig, ... }:

{
  # Helper shell scripts packaged as binaries
  environment.systemPackages = with pkgs; [
    (writeShellScriptBin "setup_nixos_config" '' # Automate /etc/nixos setup for nixos-rebuild
      set -euo pipefail

      if [ "$EUID" -ne 0 ]; then
        echo "This needs to be run as root."
        exit 1
      fi

      echo "[setup_nixos_config] Preparing /etc/nixos for nixos-rebuild..."
      mkdir -p /etc/nixos

      # Generate hardware config if missing
      if [ ! -f /etc/nixos/hardware-configuration.nix ]; then
        echo "[setup_nixos_config] Generating hardware-configuration.nix"
        nixos-generate-config --root /
      fi

      # Write minimal configuration.nix that imports hardware config and enables flakes
      cat >/etc/nixos/configuration.nix <<'EOF_CONF'
{ config, pkgs, lib, ... }:
{
  imports = [
    ./hardware-configuration.nix
  ];

  # Ensure nix flakes are enabled on the target system
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.substituters = [ "https://shimboot-systemd-nixos.cachix.org" ];
  nix.settings.trusted-public-keys = [ "shimboot-systemd-nixos.cachix.org-1:vCWmEtJq7hA2UOLN0s3njnGs9/EuX06kD7qOJMo2kAA=" ];

  # Minimal essentials
  networking.hostName = "shimboot";
  services.getty.autologinUser = userConfig.user.username;

  system.stateVersion = "24.11";
}
EOF_CONF

      # Write a minimal flake that points to the above configuration
      cat >/etc/nixos/flake.nix <<'EOF_FLAKE'
{
  description = "Shimboot minimal flake for nixos-rebuild on device";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs, ... }:
  let
    system = "x86_64-linux";
  in {
    nixosConfigurations.shimboot-host = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        ./configuration.nix
      ];
    };
  };
}
EOF_FLAKE

      echo
      echo "[setup_nixos_config] /etc/nixos set. Test with:"
      echo "  sudo nixos-rebuild switch --flake /etc/nixos#shimboot-host"
      echo
      echo "If you need to modify the config, edit /etc/nixos/configuration.nix and re-run the switch command."
      echo "[setup_nixos_config] Done."
    '')

    (writeShellScriptBin "setup_nixos" '' # Interactive post-install setup
      set -euo pipefail

      default_repo="https://github.com/PopCat19/nixos-shimboot.git"
      config_dir="$HOME/nixos-config"

      prompt_yes_no() {
        # Usage: prompt_yes_no "Question" "Y" or "n" (default)
        local question="$1"
        local default_choice="$2"
        local prompt="[Y/n]"
        if [ "$default_choice" = "n" ]; then
          prompt="[y/N]"
        fi
        local reply
        read -r -p "$question $prompt " reply
        reply="$(echo "''${reply:-}" | tr '[:upper:]' '[:lower:]')"
        if [ -z "$reply" ]; then
          if [ "$default_choice" = "n" ]; then
            return 1
          else
            return 0
          fi
        fi
        case "$reply" in
          y|yes) return 0 ;;
          n|no)  return 1 ;;
          *)     # default fallback
                  if [ "$default_choice" = "n" ]; then
                    return 1
                  else
                    return 0
                  fi
                  ;;
        esac
      }

      echo "=== Step 1: Configure Wi-Fi with nmcli ==="
      if command -v nmcli >/dev/null 2>&1; then
        echo "Scanning for Wi-Fi networks..."
        nmcli dev wifi rescan >/dev/null 2>&1 || true
        nmcli -f SSID,SECURITY,SIGNAL dev wifi list | sed '1!b; s/^/Available networks:\\n/'

        if prompt_yes_no "Connect to a Wi-Fi network now?" "Y"; then
          read -r -p "SSID: " SSID
          if [ -z "$SSID" ]; then
            echo "No SSID provided, skipping Wi-Fi setup."
          else
            read -r -s -p "PSK (hidden): " PSK
            echo
            echo "Connecting to '$SSID'..."
            if nmcli dev wifi connect "$SSID" password "$PSK"; then
              echo "Connected to '$SSID'."
              # Try to set autoconnect
              CONN_NAME="$(nmcli -t -f NAME,TYPE connection show | awk -F: '$2 == "802-11-wireless" {print $1; exit}')"
              if [ -n "$CONN_NAME" ]; then
                nmcli connection modify "$CONN_NAME" connection.autoconnect yes || true
              fi
            else
              echo "Failed to connect via nmcli dev wifi connect. Trying to create a connection..."
              nmcli connection add type wifi ifname "*" con-name "$SSID" ssid "$SSID" || true
              nmcli connection modify "$SSID" wifi-sec.key-mgmt wpa-psk wifi-sec.psk "$PSK" || true
              nmcli connection up "$SSID" || echo "Bring-up failed; please verify credentials later."
            fi
          fi
        else
          echo "Skipping Wi-Fi setup."
        fi
      else
        echo "nmcli not found. Ensure NetworkManager is installed/enabled if Wi-Fi is needed."
      fi
      echo

      echo "=== Step 2: Expand root filesystem (allocate full USB space) ==="
      if prompt_yes_no "Execute 'sudo expand_rootfs' now?" "Y"; then
        if command -v expand_rootfs >/dev/null 2>&1; then
          sudo expand_rootfs || echo "expand_rootfs encountered an error. Review the logs above."
        else
          echo "expand_rootfs is not available on PATH."
        fi
      else
        echo "Skipping root filesystem expansion."
      fi
      echo

      echo "=== Step 3: Clone flake into ~/nixos-config ==="
      read -r -p "Enter flake git remote (default: $default_repo): " repo_url
      repo_url="''${repo_url:-$default_repo}"
      read -r -p "Enter branch to checkout (leave blank for repo default): " repo_branch
      mkdir -p "$HOME"
      cd "$HOME"

      if [ -d "$config_dir/.git" ] || [ -d "$config_dir" ]; then
        echo "'$config_dir' already exists. Skipping clone."
        # If a branch was provided and repo exists, attempt to switch to it
        if [ -n "''${repo_branch:-}" ]; then
          echo "Attempting to switch existing repo to branch '$repo_branch'..."
          if command -v git >/dev/null 2>&1; then
            (
              cd "$config_dir" && \
              git fetch origin "''${repo_branch}" || true
              if git show-ref --verify --quiet "refs/heads/''${repo_branch}"; then
                git checkout "''${repo_branch}" || true
              elif git ls-remote --exit-code --heads origin "''${repo_branch}" >/dev/null 2>&1; then
                git checkout -B "''${repo_branch}" "origin/''${repo_branch}" || true
              else
                echo "Branch '$repo_branch' not found locally or on origin; leaving current branch unchanged."
              fi
            )
          fi
        fi
      else
        echo "Cloning '$repo_url' into '$config_dir'..."
        if [ -n "''${repo_branch:-}" ]; then
          if ! git clone --branch "$repo_branch" --single-branch "$repo_url" "$config_dir"; then
            echo "Clone with branch '$repo_branch' failed. Falling back to default branch..."
            if ! git clone "$repo_url" "$config_dir"; then
              echo "Clone failed. Please verify the URL and network connectivity."
            fi
          fi
        else
          if ! git clone "$repo_url" "$config_dir"; then
            echo "Clone failed. Please verify the URL and network connectivity."
          fi
        fi
      fi
      echo

      echo "=== Step 4: Rebuild NixOS from flake ==="
      cd "$config_dir" 2>/dev/null || {
        echo "Directory '$config_dir' not found; cannot rebuild. Exiting rebuild step."
        fastfetch || true
        exit 0
      }

      target_host="''${HOSTNAME:-nixos-shimboot}"
      echo "Default rebuild target: .#$target_host"

      # Auto-accept flake config to avoid interactive prompts
      export NIX_CONFIG="''${NIX_CONFIG:-}
accept-flake-config = true"

      if prompt_yes_no "Run 'nixos-rebuild switch' now with flake config auto-accepted?" "Y"; then
        if command -v sudo >/dev/null 2>&1; then
          sudo NIX_CONFIG="$NIX_CONFIG" nixos-rebuild switch \
            --flake ".#$target_host" \
            --option sandbox false \
            --option accept-flake-config true \
            || echo "nixos-rebuild failed; review errors above."
        else
          echo "sudo not found. Attempting without sudo..."
          NIX_CONFIG="$NIX_CONFIG" nixos-rebuild switch \
            --flake ".#$target_host" \
            --option sandbox false \
            --option accept-flake-config true \
            || echo "nixos-rebuild failed; review errors above."
        fi
      else
        echo "Skipping nixos-rebuild."
      fi
      echo

      echo "=== Step 5: System info ==="
      fastfetch || true

      echo "Setup complete."
      exit 0
    '')
  ];
}