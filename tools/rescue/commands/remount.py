# remount.py
#
# Purpose: Remount rootfs read-write or read-only
#
# This module:
# - Remounts the target partition
# - Updates mount state in context

from __future__ import annotations

from pathlib import Path
from typing import Optional

from lib.console import log_info, log_success, log_error, confirm_action
from lib.mounts import mounted
from commands import register_command


def run_rw(mountpoint: Path, partition: Optional[Path] = None) -> int:
    """Remount read-write.
    
    Args:
        mountpoint: Current mountpoint
        partition: Partition to remount
    
    Returns:
        Exit code
    """
    if not partition:
        log_error("No partition specified")
        return 1
    
    log_info(f"Remounting {partition} read-write...")
    
    try:
        # Unmount first
        import subprocess
        subprocess.run(["umount", str(mountpoint)], check=False)
        
        # Remount rw
        with mounted(partition, mountpoint, "rw"):
            log_success("Remounted read-write")
            return 0
    except Exception as e:
        log_error(f"Failed to remount: {e}")
        return 1


def run_ro(mountpoint: Path, partition: Optional[Path] = None) -> int:
    """Remount read-only.
    
    Args:
        mountpoint: Current mountpoint
        partition: Partition to remount
    
    Returns:
        Exit code
    """
    if not partition:
        log_error("No partition specified")
        return 1
    
    log_info(f"Remounting {partition} read-only...")
    
    try:
        # Unmount first
        import subprocess
        subprocess.run(["umount", str(mountpoint)], check=False)
        
        # Remount ro
        with mounted(partition, mountpoint, "ro"):
            log_success("Remounted read-only")
            return 0
    except Exception as e:
        log_error(f"Failed to remount: {e}")
        return 1


# Register commands
register_command(
    id="remount-rw",
    name="Remount read-write",
    number="5",
    handler=run_rw,
    description="Remount rootfs as read-write",
    tested=True,
)

register_command(
    id="remount-ro",
    name="Remount read-only",
    number="6",
    handler=run_ro,
    description="Remount rootfs as read-only",
    tested=True,
)
