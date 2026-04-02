# chroot_shell.py
#
# Purpose: Drop into chroot shell with Nix environment
#
# This module:
# - Sets up chroot with essential filesystem bindings
# - Activates NixOS environment
# - Returns to menu on exit

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path
from typing import Optional

from lib.console import log_info, log_warn, log_error, log_success
from lib.mounts import chroot_bindings, find_shell_path
from commands import register_command


def create_nix_setup_script(mountpoint: Path) -> Path:
    """Create Nix environment setup script in chroot.
    
    Args:
        mountpoint: Path to chroot root
    
    Returns:
        Path to created script (relative to chroot)
    """
    script_content = '''#!/bin/sh
if [ -d "/nix/var/nix/profiles" ]; then
    if [ -x "/nix/var/nix/profiles/system/activate" ]; then
        /nix/var/nix/profiles/system/activate 2>/dev/null || true
    fi
    export PATH="/nix/var/nix/profiles/system/sw/bin:/nix/var/nix/profiles/system/sw/sbin:$PATH"
    if [ -f "/nix/var/nix/profiles/default/etc/profile.d/nix.sh" ]; then
        . "/nix/var/nix/profiles/default/etc/profile.d/nix.sh"
    fi
    export NIX_PATH="nixpkgs=/nix/var/nix/profiles/per-user/root/channels/nixos:nixos-config=/etc/nixos/configuration.nix:/nix/var/nix/profiles/per-user/root/channels"
    echo "Nix environment ready. Tools: nixos-rebuild, nix-env, nix-channel"
fi
rm -f /.rescue-nix-setup
'''
    
    script_path = mountpoint / ".rescue-nix-setup"
    script_path.write_text(script_content)
    script_path.chmod(0o755)
    return Path(".rescue-nix-setup")


def run(
    mountpoint: Path,
    partition: Optional[Path] = None,
) -> int:
    """Enter chroot shell.
    
    Args:
        mountpoint: Path to mounted rootfs
        partition: Partition path (unused, for API consistency)
    
    Returns:
        Exit code (always 0, returns to menu)
    """
    from lib.console import log_warn, log_error
    
    log_info("Entering chroot environment...")
    log_info("Type 'exit' to return to menu")
    
    # Check if filesystem is read-only and remount if needed
    test_file = mountpoint / ".write_test"
    try:
        test_file.touch()
        test_file.unlink()
    except (OSError, PermissionError):
        log_warn("Filesystem is read-only, attempting to remount...")
        if partition:
            try:
                import subprocess
                subprocess.run(["umount", str(mountpoint)], check=False)
                subprocess.run(
                    ["mount", "-o", "rw", str(partition), str(mountpoint)],
                    check=True,
                )
                log_success("Remounted read-write")
            except subprocess.CalledProcessError as e:
                log_error(f"Failed to remount: {e}")
                log_info("Use 'Remount read-write' option first")
                return 1
        else:
            log_error("Cannot remount - no partition specified")
            log_info("Use 'Remount read-write' option first")
            return 1
    
    # Find shell
    shell = find_shell_path(mountpoint)
    if not shell:
        log_info("No shell found in rootfs")
        return 1
    
    # Create setup script
    setup_script = create_nix_setup_script(mountpoint)
    
    # Verify script was created
    script_path = mountpoint / setup_script
    if not script_path.exists():
        log_error(f"Failed to create setup script at {script_path}")
        return 1
    
    try:
        with chroot_bindings(mountpoint):
            # Run shell with setup - use absolute path
            subprocess.run(
                [
                    "chroot", str(mountpoint),
                    "/bin/sh", "-c",
                    f"if [ -f /{setup_script} ]; then . /{setup_script}; fi; exec {shell}"
                ],
                check=False,
            )
        
        log_success("Returned from chroot")
        return 0
        
    except Exception as e:
        log_info(f"Chroot error: {e}")
        return 1
    finally:
        # Cleanup script
        try:
            (mountpoint / setup_script).unlink(missing_ok=True)
        except:
            pass


# Register command
register_command(
    id="chroot",
    name="Drop into chroot shell",
    number="2",
    handler=run,
    description="Enter chroot with Nix environment",
    tested=True,
)
