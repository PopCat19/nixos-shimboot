# cachix-config.nix
#
# Purpose: Configure Cachix binary cache for all builds
#
# This module:
# - Configures Nix substituters for binary cache access
# - Sets up trusted public keys for cache verification
# - Enables faster builds through cache reuse
_: {
  # Cachix configuration for all builds
  nixConfig = {
    extra-substituters = [
      "https://shimboot-systemd-nixos.cachix.org"
    ];
    extra-trusted-public-keys = [
      "shimboot-systemd-nixos.cachix.org-1:vCWmEtJq7hA2UOLN0s3njnGs9/EuX06kD7qOJMo2kAA="
    ];
  };
}
