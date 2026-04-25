# cachix.nix
#
# Purpose: Configure binary caches for faster builds
#
# This module:
# - Configures Cachix substituters for binary cache access
# - Sets up trusted public keys for cache verification
# - Enables faster builds through cache reuse
# - Provides base caches that consumers can append to
#
# Consumers: Use lib.mkAfter in your own cachix.nix to add caches
# Example:
#   nix.settings.substituters = lib.mkAfter [ "https://your-cache.cachix.org" ];
_: {
  nix.settings = {
    substituters = [
      "https://shimboot-systemd-nixos.cachix.org"
      "https://cache.numtide.com"
    ];

    trusted-public-keys = [
      "shimboot-systemd-nixos.cachix.org-1:vCWmEtJq7hA2UOLN0s3njnGs9/EuX06kD7qOJMo2kAA="
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
    ];
  };
}
