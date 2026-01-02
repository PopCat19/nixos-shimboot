# Security Configuration Module
#
# Purpose: Configure system security and authorization
# Dependencies: polkit, rtkit, bubblewrap
# Related: services.nix, users.nix, packages.nix
#
# This module:
# - Enables PolicyKit for system authorization
# - Enables rtkit for realtime scheduling
# - Provides secure privilege escalation mechanisms
# - Creates SUID wrapper for bubblewrap to bypass ChromeOS kernel restrictions
{pkgs, ...}: {
  security.polkit.enable = true;
  security.rtkit.enable = true;

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
