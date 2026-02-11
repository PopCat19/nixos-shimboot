#!/usr/bin/env fish

# Proxify Command
#
# Purpose: Run commands detached from PTY with proxy settings.
# Rationale: Decouples application lifecycle from the shell using systemd scopes.
# Related: proxy_on.fish, proxy_off.fish
#
# Note: Leverages uwsm app for scope management and redirects output to /dev/null.

function proxify
  set -l cmd_args

  # Handle stdin or arguments
  if test -z "$argv"
    if test -t 0
      echo "Usage: proxify <command> [args...]"
      return 1
    end
    set cmd_args (cat | string split " ")
  else
    set cmd_args $argv
  end

  # Check for proxy environment
  if not set -q all_proxy
    set_color yellow; echo "[WARN] No proxy env. Run: proxy_on"; set_color normal
  else
    set -l proxy_addr (string replace -r '^[^:]+://' '' "$all_proxy")
    set_color cyan; echo "[RUN] $cmd_args[1] → $proxy_addr"; set_color normal
    # Inject proxy flag for Chromium/Electron-based applications
    set cmd_args $cmd_args --proxy-server="socks5://$proxy_addr"
  end

  # Execution logic with uwsm/systemd detachment
  if command -q uwsm
    # Redirect stdout/stderr to /dev/null and background to release the PTY immediately
    uwsm app -- $cmd_args >/dev/null 2>&1 &
    disown
  else
    # Fallback to standard backgrounding and detachment
    $cmd_args >/dev/null 2>&1 &
    disown
  end
end
