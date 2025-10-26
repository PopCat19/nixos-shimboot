# Console Configuration Module
#
# Purpose: Configure console-only NixOS with multi-console fallback strategy
# Dependencies: tmux, fish, htop, networkmanager, openssh
# Related: base_configuration/configuration.nix
#
# This module:
# - Disables all graphical services and display managers
# - Configures multiple console access methods (tty2, serial, SSH, pts/0)
# - Keeps frecon-lite running for framebuffer access
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

  # Ensure /dev/pts is mounted early
  boot.specialFileSystems."/dev/pts" = {
    fsType = "devpts";
    options = [ "mode=0620" "gid=5" "ptmxmode=0666" ];
  };

  # Strategy 1: Serial console (always works if hardware available)
  systemd.services."serial-getty@ttyS0" = {
    enable = lib.mkDefault true;
    wantedBy = [ "getty.target" ];
  };

  # Strategy 2: tty2 (reliable fallback, always exists)
  systemd.services."getty@tty2" = {
    enable = true;
    wantedBy = [ "getty.target" ];
    after = [ "systemd-user-sessions.service" ];

    serviceConfig = {
      StandardInput = "tty";
      StandardOutput = "tty";
      StandardError = "journal";
      TTYPath = "/dev/tty2";
      TTYReset = "yes";
      TTYVHangup = "yes";
      TTYVTDisallocate = "yes";
      Restart = "always";
      RestartSec = "2";
    };
  };

  # Strategy 3: tty3-6 (additional fallback consoles)
  systemd.services."getty@tty3".enable = lib.mkDefault true;
  systemd.services."getty@tty4".enable = lib.mkDefault true;
  systemd.services."getty@tty5".enable = lib.mkDefault true;
  systemd.services."getty@tty6".enable = lib.mkDefault true;

  # Strategy 4: SSH (most reliable if network works)
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = lib.mkForce "yes";  # For emergency access
      PasswordAuthentication = true;
    };
    openFirewall = true;
  };

  # Strategy 5: PTY console (if frecon-lite cooperates)
  systemd.services."console-getty-pty" = {
    description = "Console Getty on frecon-lite PTY";

    # Only start if /dev/pts/0 exists
    unitConfig = {
      ConditionPathExists = "/dev/pts/0";
    };

    after = [ "systemd-user-sessions.service" "dev-pts.mount" ];
    wants = [ "systemd-user-sessions.service" ];
    wantedBy = [ "getty.target" ];

    serviceConfig = {
      Type = "idle";
      ExecStart = "${pkgs.util-linux}/bin/agetty --noclear --keep-baud pts/0 115200,38400,9600 linux";
      Restart = "always";
      RestartSec = "5";
      StandardInput = "tty";
      StandardOutput = "tty";
      StandardError = "journal";
      TTYPath = "/dev/pts/0";
      TTYReset = "yes";
      TTYVHangup = "no";
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

  # Auto-start tmux on login for pts/0 and tty2
  programs.fish.loginShellInit = lib.mkAfter ''
    # Only auto-start tmux if we're in a console TTY and not already in tmux
    if status is-login
      set current_tty (tty)
      if string match -q "/dev/pts/0" "$current_tty"; or string match -q "/dev/tty2" "$current_tty"
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
    vim
    git
    wget
    curl

    # Network management
    networkmanager

    # Console utilities
    kbd
    util-linux

    # Helpful scripts
    (writeShellScriptBin "console-help" ''
      cat << 'EOF'
      === NixOS Shimboot Console Mode ===

      You're running in console-only mode (no display manager).

      AVAILABLE CONSOLES:
        • tty2         - Primary console (should be active)
        • tty3-6       - Additional consoles
        • ttyS0        - Serial console (if hardware connected)
        • pts/0        - frecon-lite PTY (if available)
        • SSH          - Remote access (if network configured)

      TMUX SHORTCUTS (no prefix needed):
        Ctrl+Left/Right  - Switch between windows
        Ctrl+Up/Down     - Switch between panes
        Alt+Left/Right   - Navigate panes

      DEFAULT WINDOWS:
        1. Main shell (current)
        2. System monitoring (htop)
        3. System logs (journalctl -f)
        4. Network config (nmtui)

      TMUX COMMANDS (with Ctrl+B prefix):
        Ctrl+B c        - Create new window
        Ctrl+B ,        - Rename window
        Ctrl+B &        - Close window
        Ctrl+B %        - Split vertically
        Ctrl+B "        - Split horizontally
        Ctrl+B x        - Close pane

      NETWORK SETUP:
        nmtui           - Text UI for network config
        nmcli           - Command-line network tool

      SSH ACCESS:
        ssh-info        - Show SSH connection info
        ip addr         - Show IP addresses

      DEBUGGING:
        console-status  - System and console status
        tty-status      - TTY/getty service status

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
      echo "Current TTY: $(tty)"
      echo "TERM: $TERM"
      echo "TMUX: ''${TMUX:-Not in tmux}"
      echo ""

      echo "frecon-lite process:"
      pgrep -a frecon-lite || echo "  Not running (expected in console mode)"
      echo ""

      echo "Active getty services:"
      systemctl list-units 'getty@*' 'serial-getty@*' --no-legend --no-pager | \
        awk '{printf "  %-30s %s\n", $1, $3}' || echo "  No getty services found"
      echo ""

      echo "Console devices:"
      ls -l /dev/pts/0 2>/dev/null || echo "  /dev/pts/0: not available"
      ls -l /dev/tty[2-6] 2>/dev/null | head -5
      echo ""

      echo "Network status:"
      nmcli -t -f DEVICE,STATE,CONNECTION device status 2>/dev/null || echo "  NetworkManager not available"
      echo ""

      echo "IP addresses:"
      ip -4 -brief addr show | grep -v "127.0.0.1" || echo "  No IPv4 addresses"
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
      • console-help     - Show all console commands and shortcuts
      • console-status   - System information and status
      • setup_nixos      - First-time setup wizard (Wi-Fi, expand disk)
      • ssh-info         - Show SSH connection info

    QUICK ACCESS:
      • nmtui            - Configure Wi-Fi/network
      • htop             - System monitor (or Ctrl+Right to switch)
      • journalctl -f    - System logs (or Ctrl+Right x2 to switch)

    AVAILABLE CONSOLES:
      • tty2-6           - Text consoles (you're on tty2)
      • ttyS0            - Serial console
      • SSH              - Remote access (run 'ssh-info' for details)

    Run 'console-help' for full documentation.

  '';

  # Show helpful message if SSH is available
  environment.etc."issue".text = ''

    NixOS Shimboot Console Mode

    Console access available on:
    - tty2-6 (text consoles)
    - ttyS0 (serial console if hardware connected)
    - SSH (if network configured)

    Default login: ${userConfig.user.username} / nixos-shimboot

  '';

  # Disable power management that requires X/Wayland
  services.tlp.enable = lib.mkForce false;

  # Console font (for frecon-lite and TTYs)
  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
  };

  # Ensure getty.target waits for multi-user.target
  systemd.targets.getty = {
    after = [ "multi-user.target" ];
  };
}