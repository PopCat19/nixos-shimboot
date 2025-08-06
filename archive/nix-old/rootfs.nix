# ./nix/rootfs.nix

{ pkgs, ... }:

let
  systemPackages = with pkgs; [
    systemd 
    # Add the full systemd utility suite
    systemd.dev  # includes systemd-analyze
    util-linux
    coreutils
    bash
    glibc
    busybox
    # Essential system configs
    shadow  # for /etc/passwd, /etc/group
    iana-etc  # for /etc/services, /etc/protocols
  ];
  
  closure = pkgs.closureInfo {
    rootPaths = systemPackages;
  };
  
  fhsEnv = pkgs.buildEnv {
    name = "shimboot-fhs";
    paths = systemPackages;
    ignoreCollisions = true;
  };

in pkgs.runCommand "shimboot-nixos-rootfs" {} ''
  mkdir -p $out
  cp -r ${fhsEnv}/* $out/
  
  # Copy the complete closure
  mkdir -p $out/nix/store
  while IFS= read -r storePath; do
    cp -r "$storePath" $out/nix/store/
  done < ${closure}/store-paths
  
  # Make everything writable FIRST
  chmod -R u+w $out
  
  # Fix the systemd configuration
  rm -rf $out/lib/systemd
  mkdir -p $out/lib/systemd/system
  cp -r ${pkgs.systemd}/lib/systemd/* $out/lib/systemd/
  cp -r ${pkgs.systemd}/example/systemd/system/* $out/lib/systemd/system/
  
  # Create essential directories for pseudo-filesystems AFTER chmod
  mkdir -p $out/{proc,sys,dev,run,tmp,var}

  # In the installPhase, after creating the basic directories:
  mkdir -p $out/etc/systemd/{system,user,network}
  mkdir -p $out/etc/systemd/system/{multi-user.target.wants,sysinit.target.wants}
  
  # Create a basic system.conf for systemd
  cat > $out/etc/systemd/system.conf << 'EOF'
  [Manager]
  LogTarget=journal-or-kmsg
  LogLevel=info
  LogColor=yes
  DumpCore=yes
  ShowStatus=yes
  CrashChangeVT=no
  DefaultStandardOutput=journal
  DefaultStandardError=inherit
  EOF
  
  # Ensure machine-id exists and is properly set up
  echo "$(head -c 32 /dev/urandom | base32 | tr '[:upper:]' '[:lower:]')" > $out/etc/machine-id
  
  # Ensure proper permissions
  chmod 755 $out/{proc,sys,dev,run,tmp,var}
''

# { pkgs, drivers }:
# 
# pkgs.buildEnv {
#   name = "shimboot-nixos-fhs-rootfs";
# 
#   # A list of packages whose contents will be merged together
#   # into a single FHS-style directory structure.
#   paths = with pkgs; [
#     # The core system, with our patch
#     systemd
# 
#     # The essential XFCE desktop components
#     xfce.xfce4-session
#     xfce.xfce4-panel
#     xfce.xfwm4
#     xfce.xfce4-settings
#     xfce.xfce4-terminal
# 
#     # The login manager to start the graphical session
#     lightdm-gtk-greeter
# 
#     # Basic command-line tools
#     bashInteractive
#     coreutils
#     neofetch
# 
#     # Our custom package containing the Chromebook-specific drivers
#     drivers
#   ];
# 
#   # We can add extra files here if needed, but for now, let's keep it simple.
#   # The 'paths' option handles merging everything automatically.
# }
