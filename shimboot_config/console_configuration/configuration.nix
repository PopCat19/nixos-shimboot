# Console Configuration Module
#
# Purpose: Configure console-only NixOS with frecon-lite + tmux
# Dependencies: tmux, fish, htop, networkmanager
# Related: base_configuration/configuration.nix
#
# This module:
# - Disables all graphical services and display managers
# - Configures getty on PTY0 for frecon-lite console
# - Sets up tmux with pre-configured sessions
# - Provides console-specific helper scripts and MOTD

{
  config,
  pkgs,
  lib,
  userConfig,
  ...
}: {
  # DISABLE all graphical services
  services.xserver.enable = lib.mkForce false;
  services.xserver.displayManager.lightdm.enable = lib.mkForce false;
  programs.hyprland.enable = lib.mkForce false;

  # DISABLE kill-frecon (we want to keep frecon-lite running)
  systemd.services.kill-frecon.enable = lib.mkForce false;

  # Enable getty on PTY0 (where frecon-lite provides console)
  systemd.services."getty@pts0" = {
    enable = true;
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-user-sessions.service" ];

    serviceConfig = {
      StandardInput = "tty";
      StandardOutput = "tty";
      StandardError = "journal";
      TTYPath = "/dev/pts/0";
      TTYReset = "yes";
      Restart = "always";
      RestartSec = "2s";

      # Don't try to lock console (frecon-lite already has it)
      UtmpIdentifier = "pts0";
    };
  };

  # Configure tmux for multiplexing
  programs.tmux = {
    enable = true;
    terminal = "screen-256color";
    keyMode = "vi";
    escapeTime = 0;

    extraConfig = ''
      # Easier navigation (no Ctrl+B prefix needed)
      bind-key -n C-Left previous-window
      bind-key -n C-Right next-window
      bind-key -n C-Up select-pane -U
      bind-key -n C-Down select-pane -D
      bind-key -n M-Left select-pane -L
      bind-key -n M-Right select-pane -R

      # Create default session with useful windows
      new-session -s console -d
      new-window -t console:2 -n monitoring 'exec htop'
      new-window -t console:3 -n logs 'exec journalctl -f'
      new-window -t console:4 -n network 'exec nmtui'
      select-window -t console:1

      # Status bar
      set -g status-bg black
      set -g status-fg cyan
      set -g status-left "[Console Mode] "
      set -g status-right "%H:%M %d-%b-%y"

      # Highlight active window
      set -g window-status-current-style "bg=blue,fg=white,bold"

      # Mouse support
      set -g mouse on
    '';
  };

  # Auto-start tmux on login
  programs.fish.loginShellInit = lib.mkAfter ''
    # Only auto-start tmux if we're in PTY0 and not already in tmux
    if status is-login
      if test "$TTY" = "/dev/pts/0"
        if not set -q TMUX
          echo "Starting console tmux session..."
          exec tmux new-session -A -s console
        end
      end
    end
  '';

  # Console-specific packages
  environment.systemPackages = with pkgs; [
    tmux
    htop
    bottom  # Modern htop alternative
    ncdu    # Disk usage analyzer
    ranger  # File manager
    vim
    neovim
    git
    wget
    curl
    ripgrep
    fd
    bat
    eza

    # Network management
    networkmanager

    # Helpful scripts
    (writeShellScriptBin "console-help" ''
      cat << 'EOF'
      === NixOS Shimboot Console Mode ===

      You're running in console-only mode (no display manager).
      This session uses frecon-lite + tmux for terminal multiplexing.

      TMUX SHORTCUTS (no prefix needed):
        Ctrl+Left/Right  - Switch between windows
        Ctrl+Up/Down     - Switch between panes
        Alt+Left/Right   - Navigate panes

      DEFAULT WINDOWS:
        1. Main shell (current)
        2. System monitoring (htop)
        3. System logs (journalctl -f)
        4. Network config (nmtui)

      CREATE NEW WINDOW:
        Ctrl+B c        - Create new window
        Ctrl+B ,        - Rename window
        Ctrl+B &        - Close window

      SPLIT PANES:
        Ctrl+B %        - Split vertically
        Ctrl+B "        - Split horizontally
        Ctrl+B x        - Close pane

      NETWORK SETUP:
        nmtui           - Text UI for network config
        nmcli           - Command-line network tool

      SSH ACCESS:
        ssh-info        - Show SSH connection info

      SWITCH TO GRAPHICAL MODE:
        Flash the 'full' or 'minimal' rootfs instead.
        Console mode doesn't support runtime switching.

      DOCUMENTATION:
        https://github.com/popcat19/nixos-shimboot
      EOF
    '')

    (writeShellScriptBin "console-status" ''
      echo "=== Console Mode Status ==="
      echo ""
      echo "TTY: $(tty)"
      echo "TERM: $TERM"
      echo "TMUX: ''${TMUX:-Not in tmux}"
      echo ""
      echo "frecon-lite process:"
      pgrep -a frecon-lite || echo "  Not running (unexpected!)"
      echo ""
      echo "Network status:"
      nmcli -t -f DEVICE,STATE,CONNECTION device status
      echo ""
      echo "Memory usage:"
      free -h
      echo ""
      echo "Disk usage:"
      df -h /
    '')
  ];

  # Helpful MOTD
  environment.etc."motd".text = ''

    ╔══════════════════════════════════════════════════════════════╗
    ║                NixOS Shimboot - Console Mode                 ║
    ╚══════════════════════════════════════════════════════════════╝

    This is a console-only build without display manager or desktop.

    GETTING STARTED:
      • console-help     - Show tmux shortcuts and tips
      • console-status   - System information
      • setup_nixos      - First-time setup wizard
      • ssh-info         - Enable remote SSH access

    NETWORK:
      • nmtui            - Text-based network config
      • WiFi window      - Switch to window 4 (Ctrl+Right x3)

    MONITORING:
      • htop window      - Switch to window 2 (Ctrl+Right)
      • Logs window      - Switch to window 3 (Ctrl+Right x2)

    Run 'console-help' for full documentation.

  '';

  # Disable power management that requires X/Wayland
  services.tlp.enable = lib.mkForce false;

  # Console font (for frecon-lite)
  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
  };
}