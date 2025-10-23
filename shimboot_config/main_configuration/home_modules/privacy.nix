# Privacy and security tools configuration
{
  pkgs,
  config,
  lib,
  userConfig,
  ...
}: let
  passwordsDir = "${userConfig.directories.home}/Passwords";
  keepassDb = "${passwordsDir}/keepass.kdbx";

  # Wrapper to open KeePassXC with the synced DB if it exists, else normal launch
  kpxcWrapper = pkgs.writeShellScriptBin "kpxc" ''
    set -e
    DB="${keepassDb}"
    if [ -f "$DB" ]; then
      exec ${pkgs.keepassxc}/bin/keepassxc "$DB" "$@"
    else
      exec ${pkgs.keepassxc}/bin/keepassxc "$@"
    fi
  '';
in {
  # Packages
  home.packages = with pkgs; [
    keepassxc
    kpxcWrapper
  ];

  # Ensure passwords directory exists (Syncthing also ensures this; harmless if duplicate)
  home.activation.createPasswordsDir = lib.hm.dag.entryAfter ["writeBoundary"] ''
    mkdir -p ${passwordsDir}
  '';
}
