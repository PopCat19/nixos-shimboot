# Cachix Configuration Module
#
# Purpose: Configure Cachix binary cache for all builds
# Dependencies: None
# Related: flake.nix
#
# This module:
# - Configures Nix substituters for binary cache access
# - Sets up trusted public keys for cache verification
# - Enables faster builds through cache reuse
{
  self,
  nixpkgs,
  ...
}: {
  # Cachix configuration for all builds
  nixConfig = {
    extra-substituters = [
      "https://cache.nixos.org"
      "https://shimboot-systemd-nixos.cachix.org"
    ];
    extra-trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "shimboot-systemd-nixos.cachix.org-1:vCWmEtJq7hA2UOLN0s3njnGs9/EuX06kD7qOJMo2kAA="
    ];
  };
}
