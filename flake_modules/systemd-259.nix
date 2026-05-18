# systemd-259.nix
#
# Purpose: Build systemd 259.5 using nixpkgs-unstable packages (zero old-nixpkgs imports)
#
# Problem: nixpkgs-259 build deps (python3, bison, swig, openssl…) are uncached,
# causing 89 derivations to compile locally on every systemd rebuild.
#
# Solution: Standalone derivation that fetches systemd 259.5 source + NixOS patches
# from this repo, but resolves ALL build dependencies from nixpkgs-unstable (Hydra-cached).
# Only systemd itself compiles locally.
#
# Context: ChromeOS shim kernels (dedede 5.4.85) lack mount_setattr (kernel 5.12).
# Systemd 260 requires it; 259.5 has graceful fallbacks.
# See: https://github.com/ading2210/shimboot/issues/405
{ pkgs, patchesDir }:
let
  inherit (pkgs) lib stdenv fetchFromGitHub;

  nixosPatchesDir = patchesDir + "/systemd-nixos";

  releaseTimestamp = "1766012573";

  # --- Shared derivation body ---
  # Used by both systemd259 (full) and systemdMinimal259 (minimal)
  mkSystemd =
    {
      pname ? "systemd",
      withAcl,
      withAnalyze,
      withApparmor,
      withAudit,
      withCompression,
      withCoredump,
      withCryptsetup,
      withRepart,
      withDocumentation,
      withEfi,
      withFido2,
      withFirstboot,
      withGcrypt,
      withHostnamed,
      withHomed,
      withHwdb,
      withImportd,
      withKernelInstall,
      withLibBPF,
      withLibidn2,
      withLocaled,
      withLogind,
      withMachined,
      withNetworkd,
      withNss,
      withOomd,
      withOpenSSL,
      withPam,
      withPasswordQuality,
      withPCRE2,
      withPolkit,
      withPortabled,
      withQrencode,
      withRemote,
      withResolved,
      withShellCompletions,
      withSysusers,
      withSysupdate,
      withTimedated,
      withTimesyncd,
      withTpm2Tss,
      withUkify,
      withUserDb,
      withUtmp,
      withVmspawn,
      withNspawn,
      withVConsole,
      withKmod ? true,
      withLogTrace ? false,
      withKexectools ? false,
      withLibseccomp ? true,
      withSelinux ? false,
      withLibarchive ? true,
      withTests ? false,
      buildLibsOnly ? false,
    }:

    let
      wantCurl = withRemote || withImportd;
    in
    stdenv.mkDerivation (finalAttrs: {
      inherit pname;
      version = "259.5";

      src = fetchFromGitHub {
        owner = "systemd";
        repo = "systemd";
        rev = "v259.5";
        hash = "sha256-4w5tszZd6pBJLVGop3kBy3A9DI3YeQCvIuand7oLiL0=";
      };

      # NixOS patches from the nixpkgs-259 source tree.
      # Our local patches/systemd-nixos/ is a copy from a different nixpkgs
      # revision; patch 0019 there is install-unit_file_exists (not in 259's set)
      # and patch 0020 is the timesyncd one nixpkgs-259 calls 0019.
      # Use exact filenames matching what nixpkgs-259 had.
      patches =
        [
          (nixosPatchesDir + "/0001-Start-device-units-for-uninitialised-encrypted-devic.patch")
          (nixosPatchesDir + "/0002-Don-t-try-to-unmount-nix-or-nix-store.patch")
          (nixosPatchesDir + "/0003-Fix-NixOS-containers.patch")
          (nixosPatchesDir + "/0004-Add-some-NixOS-specific-unit-directories.patch")
          (nixosPatchesDir + "/0005-Get-rid-of-a-useless-message-in-user-sessions.patch")
          (nixosPatchesDir + "/0006-hostnamed-localed-timedated-disable-methods-that-cha.patch")
          (nixosPatchesDir + "/0007-Change-usr-share-zoneinfo-to-etc-zoneinfo.patch")
          (nixosPatchesDir + "/0008-localectl-use-etc-X11-xkb-for-list-x11.patch")
          (nixosPatchesDir + "/0009-add-rootprefix-to-lookup-dir-paths.patch")
          (nixosPatchesDir + "/0010-systemd-shutdown-execute-scripts-in-etc-systemd-syst.patch")
          (nixosPatchesDir + "/0011-systemd-sleep-execute-scripts-in-etc-systemd-system-.patch")
          (nixosPatchesDir + "/0012-path-util.h-add-placeholder-for-DEFAULT_PATH_NORMAL.patch")
          (nixosPatchesDir + "/0013-inherit-systemd-environment-when-calling-generators.patch")
          (nixosPatchesDir + "/0014-core-don-t-taint-on-unmerged-usr.patch")
          (nixosPatchesDir + "/0015-tpm2_context_init-fix-driver-name-checking.patch")
          (nixosPatchesDir + "/0016-systemctl-edit-suggest-systemdctl-edit-runtime-on-sy.patch")
          (nixosPatchesDir + "/0017-meson.build-do-not-create-systemdstatedir.patch")
          (nixosPatchesDir + "/0018-meson-Don-t-link-ssh-dropins.patch")
        ]
        ++ lib.optionals (stdenv.hostPlatform.isLinux && stdenv.hostPlatform.isGnu) [
          (nixosPatchesDir + "/0019-timesyncd-disable-NSCD-when-DNSSEC-validation-is-dis.patch")
        ]
        # Shimboot-specific patches
        ++ [
          (patchesDir + "/systemd-mountpoint-util-chromeos.patch")
          (patchesDir + "/systemd-process-util-pidfd-fallback.patch")
        ];

      postPatch = ''
        substituteInPlace src/basic/path-util.h --replace "@defaultPathNormal@" "${builtins.placeholder "out"}/bin/"
      ''
      + lib.optionalString withLibBPF ''
        substituteInPlace meson.build \
          --replace "find_program('clang'" "find_program('${stdenv.cc.targetPrefix}clang'"
      ''
      + ''
        shopt -s extglob
        patchShebangs tools test src/!(rpm|kernel-install|ukify) src/kernel-install/test-kernel-install.sh
      '';

      outputs = [ "out" "dev" ] ++ lib.optional (!buildLibsOnly) "man";
      separateDebugInfo = true;
      __structuredAttrs = true;

      nativeBuildInputs =
        [
          pkgs.pkg-config
          pkgs.makeBinaryWrapper
          pkgs.gperf
          pkgs.ninja
          pkgs.meson
          pkgs.glibcLocales
          pkgs.m4
          pkgs.autoPatchelfHook
          pkgs.intltool
          pkgs.gettext
          pkgs.libxslt
          pkgs.docbook_xsl
          pkgs.docbook_xml_dtd_42
          pkgs.docbook_xml_dtd_45
          pkgs.bash
          (pkgs.python3Packages.python.withPackages (
            ps: with ps; [ lxml jinja2 ] ++ lib.optional withEfi ps.pyelftools
          ))
        ]
        ++ lib.optionals withLibBPF [
          pkgs.bpftools
          pkgs.llvmPackages.clang
          pkgs.llvmPackages.libllvm
        ];

      autoPatchelfFlags = [ "--keep-libc" ];

      buildInputs =
        [
          pkgs.libxcrypt
          pkgs.libuuid
          stdenv.cc.libc.linuxHeaders
        ]
        ++ lib.optionals withGcrypt [ pkgs.libgcrypt pkgs.libgpg-error ]
        ++ lib.optionals withOpenSSL [ pkgs.openssl ]
        ++ lib.optional withTests pkgs.glib
        ++ lib.optional withAcl pkgs.acl
        ++ lib.optional withApparmor pkgs.libapparmor
        ++ lib.optional withAudit pkgs.audit
        ++ lib.optional wantCurl (lib.getDev pkgs.curl)
        ++ lib.optionals withCompression [ pkgs.zlib pkgs.bzip2 pkgs.lz4 pkgs.xz pkgs.zstd ]
        ++ lib.optional withCoredump pkgs.elfutils
        ++ lib.optional withCryptsetup (lib.getDev pkgs.cryptsetup.dev)
        ++ lib.optional withKmod pkgs.kmod
        ++ lib.optional withLibidn2 pkgs.libidn2
        ++ lib.optional withLibseccomp pkgs.libseccomp
        ++ lib.optional withPam pkgs.pam
        ++ lib.optional withPCRE2 pkgs.pcre2
        ++ lib.optionals withRemote [ pkgs.libmicrohttpd pkgs.gnutls ]
        ++ lib.optionals (withHomed || withCryptsetup) [ pkgs.p11-kit pkgs.libfido2 ]
        ++ lib.optionals withLibBPF [ pkgs.libbpf ]
        ++ lib.optional withTpm2Tss pkgs.tpm2-tss
        ++ lib.optionals withPasswordQuality [ pkgs.libpwquality ]
        ++ lib.optionals withQrencode [ pkgs.qrencode ]
        ++ lib.optionals withLibarchive [ pkgs.libarchive ];

      mesonBuildType = "release";

      mesonFlags =
        [
          (lib.mesonOption "time-epoch" releaseTimestamp)
          (lib.mesonOption "version-tag" finalAttrs.version)
          (lib.mesonOption "mode" "release")
          (lib.mesonOption "tty-gid" "3")
          (lib.mesonOption "pamconfdir" "${builtins.placeholder "out"}/etc/pam.d")
          (lib.mesonOption "shellprofiledir" "${builtins.placeholder "out"}/etc/profile.d")
          (lib.mesonOption "debug-shell" "/bin/sh")
          (lib.mesonOption "default-user-shell" "/run/current-system/sw/bin/bash")
          (lib.mesonOption "split-bin" "false")
          (lib.mesonOption "dbuspolicydir" "${builtins.placeholder "out"}/share/dbus-1/system.d")
          (lib.mesonOption "dbussessionservicedir" "${builtins.placeholder "out"}/share/dbus-1/services")
          (lib.mesonOption "dbussystemservicedir" "${builtins.placeholder "out"}/share/dbus-1/system-services")
          (lib.mesonOption "pkgconfiglibdir" "${builtins.placeholder "dev"}/lib/pkgconfig")
          (lib.mesonOption "pkgconfigdatadir" "${builtins.placeholder "dev"}/share/pkgconfig")
          (lib.mesonOption "sbat-distro" "nixos")
          (lib.mesonOption "sbat-distro-summary" "NixOS")
          (lib.mesonOption "sbat-distro-url" "https://nixos.org/")
          (lib.mesonOption "sbat-distro-pkgname" pname)
          (lib.mesonOption "sbat-distro-version" finalAttrs.version)
          (lib.mesonOption "system-uid-max" "999")
          (lib.mesonOption "system-gid-max" "999")
          (lib.mesonOption "sysvinit-path" "")
          (lib.mesonOption "sysvrcnd-path" "")
          (lib.mesonOption "sulogin-path" "${lib.getOutput "login" pkgs.util-linux}/bin/sulogin")
          (lib.mesonOption "nologin-path" "${lib.getOutput "login" pkgs.util-linux}/bin/nologin")
          (lib.mesonOption "mount-path" "${lib.getOutput "mount" pkgs.util-linux}/bin/mount")
          (lib.mesonOption "umount-path" "${lib.getOutput "mount" pkgs.util-linux}/bin/umount")
          (lib.mesonOption "swapon-path" "${lib.getOutput "swap" pkgs.util-linux}/sbin/swapon")
          (lib.mesonOption "swapoff-path" "${lib.getOutput "swap" pkgs.util-linux}/sbin/swapoff")
          (lib.mesonOption "sshconfdir" "")
          (lib.mesonOption "sshdconfdir" "no")
          (lib.mesonOption "rpmmacrosdir" "no")

          # Features
          (lib.mesonBool "tests" withTests)
          (lib.mesonEnable "glib" withTests)
          (lib.mesonEnable "dbus" withTests)
          (lib.mesonEnable "bzip2" withCompression)
          (lib.mesonEnable "lz4" withCompression)
          (lib.mesonEnable "xz" withCompression)
          (lib.mesonEnable "zstd" withCompression)
          (lib.mesonEnable "zlib" withCompression)
          (lib.mesonEnable "nss-mymachines" (withNss && withMachined))
          (lib.mesonEnable "nss-resolve" withNss)
          (lib.mesonBool "nss-myhostname" withNss)
          (lib.mesonBool "nss-systemd" withNss)
          (lib.mesonEnable "libcryptsetup" withCryptsetup)
          (lib.mesonEnable "libcryptsetup-plugins" withCryptsetup)
          (lib.mesonEnable "p11kit" (withHomed || withCryptsetup))
          (lib.mesonEnable "libfido2" withFido2)
          (lib.mesonEnable "openssl" withOpenSSL)
          (lib.mesonEnable "pwquality" withPasswordQuality)
          (lib.mesonEnable "passwdqc" false)
          (lib.mesonEnable "remote" withRemote)
          (lib.mesonEnable "microhttpd" withRemote)
          (lib.mesonEnable "pam" withPam)
          (lib.mesonEnable "acl" withAcl)
          (lib.mesonEnable "audit" withAudit)
          (lib.mesonEnable "apparmor" withApparmor)
          (lib.mesonEnable "gcrypt" withGcrypt)
          (lib.mesonEnable "importd" withImportd)
          (lib.mesonEnable "homed" withHomed)
          (lib.mesonEnable "polkit" withPolkit)
          (lib.mesonEnable "elfutils" withCoredump)
          (lib.mesonEnable "libcurl" wantCurl)
          (lib.mesonEnable "libidn" false)
          (lib.mesonEnable "libidn2" withLibidn2)
          (lib.mesonEnable "repart" withRepart)
          (lib.mesonEnable "sysupdate" withSysupdate)
          (lib.mesonEnable "sysupdated" withSysupdate)
          (lib.mesonEnable "seccomp" withLibseccomp)
          (lib.mesonEnable "selinux" withSelinux)
          (lib.mesonEnable "tpm2" withTpm2Tss)
          (lib.mesonEnable "pcre2" withPCRE2)
          (lib.mesonEnable "bpf-framework" withLibBPF)
          (lib.mesonEnable "bootloader" false)
          (lib.mesonEnable "ukify" withUkify)
          (lib.mesonEnable "kmod" withKmod)
          (lib.mesonEnable "qrencode" withQrencode)
          (lib.mesonEnable "vmspawn" withVmspawn)
          (lib.mesonEnable "libarchive" withLibarchive)
          (lib.mesonEnable "xenctrl" false)
          (lib.mesonEnable "gnutls" false)
          (lib.mesonEnable "xkbcommon" false)
          (lib.mesonEnable "man" true)
          (lib.mesonEnable "nspawn" withNspawn)
          (lib.mesonBool "vconsole" withVConsole)
          (lib.mesonBool "analyze" withAnalyze)
          (lib.mesonBool "logind" withLogind)
          (lib.mesonBool "localed" withLocaled)
          (lib.mesonBool "hostnamed" withHostnamed)
          (lib.mesonBool "machined" withMachined)
          (lib.mesonBool "networkd" withNetworkd)
          (lib.mesonBool "oomd" withOomd)
          (lib.mesonBool "portabled" withPortabled)
          (lib.mesonBool "hwdb" withHwdb)
          (lib.mesonBool "timedated" withTimedated)
          (lib.mesonBool "timesyncd" withTimesyncd)
          (lib.mesonBool "userdb" withUserDb)
          (lib.mesonBool "coredump" withCoredump)
          (lib.mesonBool "firstboot" withFirstboot)
          (lib.mesonBool "resolve" withResolved)
          (lib.mesonBool "sysusers" withSysusers)
          (lib.mesonBool "efi" withEfi)
          (lib.mesonBool "utmp" withUtmp)
          (lib.mesonBool "log-trace" withLogTrace)
          (lib.mesonBool "kernel-install" withKernelInstall)
          (lib.mesonBool "quotacheck" false)
          (lib.mesonBool "ldconfig" false)
          (lib.mesonBool "install-sysconfdir" false)
          (lib.mesonBool "create-log-dirs" false)
          (lib.mesonBool "smack" true)
          (lib.mesonBool "b_pie" true)
        ]
        ++ lib.optionals withVConsole [
          (lib.mesonOption "loadkeys-path" "${pkgs.kbd}/bin/loadkeys")
          (lib.mesonOption "setfont-path" "${pkgs.kbd}/bin/setfont")
        ]
        ++ lib.optionals (withShellCompletions == false) [
          (lib.mesonOption "bashcompletiondir" "no")
          (lib.mesonOption "zshcompletiondir" "no")
        ];

      preConfigure = ''
        mesonFlagsArray+=(-Dntp-servers="0.nixos.pool.ntp.org 1.nixos.pool.ntp.org 2.nixos.pool.ntp.org 3.nixos.pool.ntp.org")
        export LC_ALL="en_US.UTF-8";

        substituteInPlace man/systemd-makefs@.service.xml \
          --replace '/sbin/mkswap' '${lib.getBin pkgs.util-linux}/sbin/mkswap'
        substituteInPlace man/systemd-analyze.xml \
          --replace '/bin/echo' '${pkgs.coreutils}/bin/echo'
        substituteInPlace man/systemd.service.xml \
          --replace '/bin/echo' '${pkgs.coreutils}/bin/echo'
        substituteInPlace man/systemd-run.xml \
          --replace '/bin/echo' '${pkgs.coreutils}/bin/echo'
        substituteInPlace src/analyze/test-verify.c \
          --replace '/bin/echo' '${pkgs.coreutils}/bin/echo'
        substituteInPlace src/test/test-env-file.c \
          --replace '/bin/echo' '${pkgs.coreutils}/bin/echo'
        substituteInPlace src/test/test-fileio.c \
          --replace '/bin/echo' '${pkgs.coreutils}/bin/echo'
        substituteInPlace src/test/test-load-fragment.c \
          --replace '/bin/echo' '${pkgs.coreutils}/bin/echo'
        substituteInPlace test/test-execute/exec-noexecpaths-simple.service \
          --replace '/bin/cat' '${pkgs.coreutils}/bin/cat'
        substituteInPlace src/journal/cat.c \
          --replace '/bin/cat' '${pkgs.coreutils}/bin/cat'
        substituteInPlace man/systemd-fsck@.service.xml \
          --replace '/usr/lib/systemd/systemd-fsck' "$out/lib/systemd/systemd-fsck"

        substituteInPlace src/libsystemd/sd-journal/catalog.c \
          --replace /usr/lib/systemd/catalog/ $out/lib/systemd/catalog/
      '';

      postConfigure = ''
        substituteInPlace config.h \
          --replace "POLKIT_AGENT_BINARY_PATH" "_POLKIT_AGENT_BINARY_PATH" \
          --replace "SYSTEMD_BINARY_PATH" "_SYSTEMD_BINARY_PATH" \
          --replace "SYSTEMD_CGROUP_AGENTS_PATH" "_SYSTEMD_CGROUP_AGENT_PATH"
      '';

      env.NIX_CFLAGS_COMPILE = toString [
        "-UPOLKIT_AGENT_BINARY_PATH"
        "-DPOLKIT_AGENT_BINARY_PATH=\"/run/current-system/sw/bin/pkttyagent\""
        "-USYSTEMD_CGROUP_AGENTS_PATH"
        "-DSYSTEMD_CGROUP_AGENTS_PATH=\"/run/current-system/systemd/lib/systemd/systemd-cgroups-agent\""
        "-USYSTEMD_BINARY_PATH"
        "-DSYSTEMD_BINARY_PATH=\"/run/current-system/systemd/lib/systemd/systemd\""
      ];

      doCheck = false;

      preInstall = ''
        export DESTDIR=/
      '';

      postInstall =
        lib.optionalString (!buildLibsOnly) ''
          mkdir -p $out/example/systemd
          mv $out/lib/{binfmt.d,sysctl.d,tmpfiles.d} $out/example
          mv $out/lib/systemd/{system,user} $out/example/systemd

          rm -rf $out/etc/systemd/system

          for i in $out/share/dbus-1/system-services/*.service; do
            substituteInPlace $i --replace /bin/false ${pkgs.coreutils}/bin/false
          done

          ln -s bin "$out/sbin"
          rm -rf $out/etc/rpm

          # Create NOOP stubs for units added after 259.5 but expected
          # by nixos-unstable modules
          UNITDIR="$out/example/systemd/system"
          mkdir -p "$UNITDIR"

          for unit in breakpoint-pre-udev.service breakpoint-pre-basic.service breakpoint-pre-mount.service breakpoint-pre-switch-root.service systemd-factory-reset-complete.service systemd-journalctl@.service systemd-bsod.service; do
            if [ ! -e "$UNITDIR/$unit" ]; then
              name="$(echo "$unit" | sed 's/\..*$//')"
              printf '[Unit]\nDescription=%s (stub - not in 259.5)\nDefaultDependencies=no\nRefuseManualStart=yes\n\n[Service]\nType=oneshot\nExecStart=/bin/true\nRemainAfterExit=yes\n' "$name" > "$UNITDIR/$unit"
            fi
          done

          if [ ! -e "$UNITDIR/factory-reset-now.target" ]; then
            printf '[Unit]\nDescription=factory-reset-now (stub - not in 259.5)\nRefuseManualStart=yes\n' > "$UNITDIR/factory-reset-now.target"
          fi

          if [ ! -e "$UNITDIR/systemd-journalctl.socket" ]; then
            printf '[Unit]\nDescription=systemd-journalctl (stub - not in 259.5)\nDefaultDependencies=no\nBefore=sockets.target\n\n[Socket]\nListenStream=/run/systemd/io.systemd.JournalAccess\nSymlinks=/run/varlink/registry/io.systemd.JournalAccess\nFileDescriptorName=varlink\n' > "$UNITDIR/systemd-journalctl.socket"
          fi

          mkdir -p "$UNITDIR/factory-reset.target.wants"

          BINDIR="$out/lib/systemd"
          mkdir -p "$BINDIR/system-generators"
          for bin in systemd-factory-reset system-generators/systemd-factory-reset-generator; do
            if [ ! -e "$BINDIR/$bin" ]; then
              printf '#!/bin/sh\n# Stub - not available in systemd 259.5\nexit 0\n' > "$BINDIR/$bin"
              chmod +x "$BINDIR/$bin"
            fi
          done

          # systemd-bsod needs HAVE_QRENCODE (disabled). NixOS initrd expects it.
          if [ ! -e "$out/lib/systemd/systemd-bsod" ]; then
            printf '#!/bin/sh\n# Stub - qrencode disabled in systemd 259.5 build\nexit 0\n' > "$out/lib/systemd/systemd-bsod"
            chmod +x "$out/lib/systemd/systemd-bsod"
          fi
        ''
        + lib.optionalString (!withKernelInstall) ''
          find $out -name "*kernel-install*" -exec rm {} \;
        ''
        + lib.optionalString (!withDocumentation) ''
          rm -rf $out/share/doc
        ''
        + lib.optionalString (withKmod && !buildLibsOnly) ''
          mv $out/lib/modules-load.d $out/example
        ''
        + lib.optionalString withSysusers ''
          mv $out/lib/sysusers.d $out/example
        '';

      passthru = {
        interfaceVersion = 2;

        inherit
          withCryptsetup
          withEfi
          withFido2
          withHostnamed
          withImportd
          withKmod
          withLocaled
          withMachined
          withNetworkd
          withTimedated
          withTpm2Tss
          withUtmp
          ;

        withBootloader = false;
        withLogind = withLogind;
        withVconsole = withVConsole;
        withTpm2Units = withTpm2Tss && false && withOpenSSL;
        withPortabled = withPortabled;
        withSysupdate = withSysupdate;
        withNspawn = withNspawn;

        util-linux = pkgs.util-linux;
        kmod = pkgs.kmod;
        kbd = pkgs.kbd;
      };

      meta = {
        homepage = "https://systemd.io";
        description = "System and service manager for Linux";
        license = with lib.licenses; [
          bsd2 bsd3 cc0 lgpl21Plus lgpl2Plus mit mit0 ofl publicDomain
        ];
        pkgConfigModules = [ "libsystemd" "libudev" "systemd" "udev" ];
        platforms = lib.platforms.linux;
        priority = 10;
      };
    });

in
let
  # mkSystemd returns a raw mkDerivation, which has overrideAttrs but
  # not .override (the function form of mkDerivation doesn't add it).
  # nixpkgs all-packages.nix calls systemdMinimal.override {} to build
  # systemdLibs, so we need our derivations to have .override.
  # We don't need real override semantics — just provide it for compat.
  makeOverridable = drv: drv // {
    override = _: drv;
  };
in
rec {
  # Full systemd 259.5 — PID 1, udevd, all services
  # Flags match nixpkgs-259 defaults (features nixos-unstable modules expect).
  systemd259 = makeOverridable (mkSystemd {
    withAcl = true;
    withAnalyze = true;
    withApparmor = false;
    withAudit = false;
    withCompression = true;
    withCoredump = true;
    withCryptsetup = true;
    withRepart = true;
    withDocumentation = false;
    withEfi = false;
    withFido2 = false;
    withFirstboot = true;
    withGcrypt = true;
    withHostnamed = true;
    withHomed = false;
    withHwdb = true;
    withImportd = false;
    withKernelInstall = false;
    withLibBPF = false;
    withLibidn2 = false;
    withLocaled = true;
    withLogind = true;
    withMachined = false;
    withNetworkd = true;
    withNss = true;
    withOomd = true;
    withOpenSSL = true;
    withPam = true;
    withPasswordQuality = false;
    withPCRE2 = false;
    withPolkit = false;
    withPortabled = true;
    withQrencode = true;
    withRemote = false;
    withResolved = true;
    withShellCompletions = false;
    withSysusers = true;
    withSysupdate = false;
    withTimedated = true;
    withTimesyncd = true;
    withTpm2Tss = false;
    withUkify = false;
    withUserDb = false;
    withUtmp = true;
    withVmspawn = false;
    withNspawn = true;
    withVConsole = true;
    withLibarchive = false;
    withLibseccomp = true;
  });

  # Minimal systemd 259.5 — udevadm only, for udev rules verification
  systemdMinimal259 = makeOverridable (mkSystemd {
    pname = "systemd-minimal-259";
    withAcl = false;
    withAnalyze = false;
    withApparmor = false;
    withAudit = false;
    withCompression = false;
    withCoredump = false;
    withCryptsetup = false;
    withRepart = false;
    withDocumentation = false;
    withEfi = false;
    withFido2 = false;
    withFirstboot = false;
    withGcrypt = false;
    withHostnamed = false;
    withHomed = false;
    withHwdb = false;
    withImportd = false;
    withKernelInstall = false;
    withLibBPF = false;
    withLibidn2 = false;
    withLocaled = false;
    withLogind = false;
    withMachined = false;
    withNetworkd = false;
    withNss = false;
    withOomd = false;
    withOpenSSL = false;
    withPam = false;
    withPasswordQuality = false;
    withPCRE2 = false;
    withPolkit = false;
    withPortabled = false;
    withQrencode = false;
    withRemote = false;
    withResolved = false;
    withShellCompletions = false;
    withSysusers = false;
    withSysupdate = false;
    withTimedated = false;
    withTimesyncd = false;
    withTpm2Tss = false;
    withUkify = false;
    withUserDb = false;
    withUtmp = false;
    withVmspawn = false;
    withNspawn = false;
    withVConsole = false;
    withLibarchive = false;
    withLibseccomp = false;
    withKmod = false;
  });

  # Minimal systemd-libs for nixpkgs compatibility.
  # all-packages.nix does: systemdLibs = systemdMinimal.override { ... }
  # Our overlay replaces systemdMinimal, so we also replace systemdLibs
  # with a derivation that has just libsystemd + libudev + headers.
  systemdLibs259 = makeOverridable (mkSystemd {
    pname = "systemd-minimal-libs";
    withAcl = false;
    withAnalyze = false;
    withApparmor = false;
    withAudit = false;
    withCompression = false;
    withCoredump = false;
    withCryptsetup = false;
    withRepart = false;
    withDocumentation = false;
    withEfi = false;
    withFido2 = false;
    withFirstboot = false;
    withGcrypt = false;
    withHostnamed = false;
    withHomed = false;
    withHwdb = false;
    withImportd = false;
    withKernelInstall = false;
    withLibBPF = false;
    withLibidn2 = false;
    withLocaled = false;
    withLogind = false;
    withMachined = false;
    withNetworkd = false;
    withNss = false;
    withOomd = false;
    withOpenSSL = false;
    withPam = false;
    withPasswordQuality = false;
    withPCRE2 = false;
    withPolkit = false;
    withPortabled = false;
    withQrencode = false;
    withRemote = false;
    withResolved = false;
    withShellCompletions = false;
    withSysusers = false;
    withSysupdate = false;
    withTimedated = false;
    withTimesyncd = false;
    withTpm2Tss = false;
    withUkify = false;
    withUserDb = false;
    withUtmp = false;
    withVmspawn = false;
    withNspawn = false;
    withVConsole = false;
    withLibarchive = false;
    withLibseccomp = false;
    withKmod = false;
  });
}
