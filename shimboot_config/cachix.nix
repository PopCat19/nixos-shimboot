# cachix.nix
#
# Purpose: Configure binary caches for system builds
#
# This module:
# - Exports cache values for substituters and public keys
# - Used by apply-cachix.nix to apply to nix.settings
# - Enables faster builds through cache reuse
#
# Consumer pattern (add your own caches):
#   { lib, ... }:
#   {
#     nix.settings = {
#       substituters = lib.mkAfter [ "https://your-cache.cachix.org" ];
#       trusted-public-keys = lib.mkAfter [ "your-cache.cachix.org-1:..." ];
#     };
#   }
#
# Note: mkAfter appends to base caches. No need to redeclare base values.
{
  substituters = [
    "https://shimboot-systemd-nixos.cachix.org"
    "https://cache.numtide.com"
  ];

  trustedPublicKeys = [
    "shimboot-systemd-nixos.cachix.org-1:vCWmEtJq7hA2UOLN0s3njnGs9/EuX06kD7qOJMo2kAA="
    "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
  ];
}
