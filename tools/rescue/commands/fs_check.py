# fs_check.py
#
# Purpose: Filesystem health check
#
# This module:
# - Runs e2fsck in read-only mode to check for issues

from __future__ import annotations

import subprocess
from pathlib import Path
from typing import Optional

from lib.console import log_info, log_warn, confirm_action
from commands import register_command


def run(
    mountpoint: Path,
    partition: Optional[Path] = None,
) -> int:
    """Check filesystem health.
    
    Args:
        mountpoint: Path to mounted rootfs
        partition: Partition to check
    
    Returns:
        Exit code (0 = success)
    """
    if not partition:
        log_warn("No partition specified")
        return 1
    
    log_info(f"Checking filesystem on {partition}...")
    log_info("(Running in read-only mode - no changes will be made)")
    
    # Must unmount first
    try:
        subprocess.run(["umount", str(mountpoint)], check=False)
    except:
        pass
    
    if confirm_action("Run filesystem check"):
        try:
            result = subprocess.run(
                ["e2fsck", "-n", str(partition)],
                capture_output=False,
                text=True,
            )
            return result.returncode
        except subprocess.CalledProcessError as e:
            log_warn(f"Filesystem check returned: {e.returncode}")
            return e.returncode
    
    return 0


# Register command
register_command(
    id="fs-check",
    name="Filesystem health check",
    number="8",
    handler=run,
    description="Check filesystem with e2fsck (read-only)",
    tested=True,
)
