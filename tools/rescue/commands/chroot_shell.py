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

from lib.console import log_info, log_success
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
    log_info("Entering chroot environment...")
    log_info("Type 'exit' to return to menu")
    
    # Find shell
    shell = find_shell_path(mountpoint)
    if not shell:
        log_info("No shell found in rootfs")
        return 1
    
    # Create setup script
    setup_script = create_nix_setup_script(mountpoint)
    
    try:
        with chroot_bindings(mountpoint):
            # Run shell with setup
            subprocess.run(
                [
                    "chroot", str(mountpoint),
                    "/bin/sh", "-c",
                    f"if [ -f {setup_script} ]; then . {setup_script}; fi; exec {shell}"
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
