# cachix.nix
#
# Purpose: Configure binary caches for system builds
#
# This module:
# - Configures Cachix substituters for binary cache access
# - Sets up trusted public keys for cache verification
# - Enables faster builds through cache reuse
#
# Exports for consumers to merge:
#   substituters = [ "https://shimboot-systemd-nixos.cachix.org" ... ];
#   trustedPublicKeys = [ "shimboot-..." ... ];
#
# Consumer pattern:
#   { lib, ... }:
#   let cachix = import "${inputs.shimboot}/shimboot_config/cachix.nix";
#   in {
#     nix.settings = lib.mkMerge [
#       { substituters = cachix.substituters; }
#       { trusted-public-keys = cachix.trustedPublicKeys; }
#       { substituters = [ "https://your-cache.cachix.org" ]; }
#       { trusted-public-keys = [ "your-key" ]; }
#     ];
#   }
_: {
  substituters = [
    "https://shimboot-systemd-nixos.cachix.org"
    "https://cache.numtide.com"
  ];

  trustedPublicKeys = [
    "shimboot-systemd-nixos.cachix.org-1:vCWmEtJq7hA2UOLN0s3njnGs9/EuX06kD7qOJMo2kAA="
    "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
  ];
}
