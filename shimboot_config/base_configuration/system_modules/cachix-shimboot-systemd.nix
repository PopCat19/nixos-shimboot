{ lib, ... }:
{
  # Add Cachix substituter for prebuilt patched systemd to avoid recompilation on Chromebooks
  nix.settings = {
    substituters = lib.mkAfter [
      "https://shimboot-systemd-nixos.cachix.org"
    ];
    trusted-public-keys = lib.mkAfter [
      "shimboot-systemd-nixos.cachix.org-1:vCWmEtJq7hA2UOLN0s3njnGs9/EuX06kD7qOJMo2kAA="
    ];
  };
}