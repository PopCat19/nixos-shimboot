#!/usr/bin/env bash

# --- Prerequisite Checking Functions ---

# Check if script is running as root
check_not_root() {
  if [ "$EUID" -eq 0 ]; then
    print_error "Don't run this script as root! It will escalate privileges when needed."
    exit 1
  fi
}

# Check if script is running as root (for scripts that require root)
check_root() {
  if [ "$EUID" -ne 0 ]; then
    print_error "This script needs to be run as root."
    exit 1
  fi
}

# Check if required commands are available
check_commands() {
  local commands="$1"
  print_info "Checking prerequisites..."
  
  for cmd in $commands; do
    if command -v $cmd >/dev/null; then
      print_debug "✓ $cmd found at $(command -v $cmd)"
    else
      print_error "✗ $cmd not found"
      exit 1
    fi
  done
}

# Check if required files exist
check_files() {
  local files="$1"
  
  for file in $files; do
    if [ -e "$file" ]; then
      print_debug "✓ $file exists"
    else
      print_error "✗ $file not found"
      exit 1
    fi
  done
}

# Check for recovery file (optional but recommended)
check_recovery_file() {
  if [ -e "$RECOVERY_FILE" ]; then
    print_debug "✓ $RECOVERY_FILE exists - will harvest additional drivers"
    USE_RECOVERY=true
  else
    print_debug "⚠ $RECOVERY_FILE not found - skipping recovery driver harvest"
    print_debug "  Consider downloading a recovery image for better hardware support"
    USE_RECOVERY=false
  fi
}

# Validate user environment
validate_user_environment() {
  print_debug "Script PID: $$"
  print_debug "User: $USER (UID: $(id -u), GID: $(id -g))"
  print_debug "Groups: $(id -Gn)"
}

# Check all prerequisites for the build process
check_all_prerequisites() {
  check_not_root
  validate_user_environment
  check_commands "$REQUIRED_COMMANDS"
  check_files "$REQUIRED_FILES"
  check_recovery_file
  check_sudo
}