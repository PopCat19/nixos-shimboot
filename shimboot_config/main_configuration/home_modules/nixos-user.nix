# DEPRECATED: Use home.nix instead of nixos-user.nix
# This file remains for backward compatibility and forwards to home.nix.
{ ... } @ args:
  builtins.trace "DEPRECATED: shimboot_config/main_configuration/home_modules/nixos-user.nix is deprecated; use home.nix" ((import ./home.nix) args)