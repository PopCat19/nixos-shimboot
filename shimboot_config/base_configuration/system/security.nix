# Security Configuration Module
#
# Purpose: Configure system security and authorization
# Dependencies: polkit, rtkit, bubblewrap, systemd
# Related: services.nix, users.nix, packages.nix
#
# This module:
# - Enables PolicyKit for system authorization
# - Enables rtkit for realtime scheduling
# - Disables systemd coredumps for disk space and privacy
# - Provides secure privilege escalation mechanisms
# - Creates SUID wrapper for bubblewrap to bypass ChromeOS kernel restrictions
{ pkgs, ... }:
{
  security.polkit.enable = true;
  security.rtkit.enable = true;

  # Disable coredumps to save disk space and improve performance
  systemd.coredump.enable = false;

  # Create a Set-UID wrapper for Bubblewrap
  # This allows bwrap to create namespaces even if the kernel
  # restricts unprivileged user namespaces (common in ChromeOS kernels).
  security.wrappers.bwrap = {
    owner = "root";
    group = "root";
    source = "${pkgs.bubblewrap}/bin/bwrap";
    setuid = true;
  };

  # Ensure the wrapper is in the system path
  # Programs looking for 'bwrap' will find the SUID version first.
  environment.systemPackages = [
    pkgs.bubblewrap
  ];
}
