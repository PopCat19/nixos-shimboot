# home_mgmt.py
#
# Purpose: Home directory backup/export [UNTESTED]
#
# This module:
# - Exports home directories to archives
# - Imports home from archives
# - Lists home contents

from __future__ import annotations

from pathlib import Path
from typing import Optional

from lib.console import log_warn, log_section
from commands import register_command


def run(
    mountpoint: Path,
    partition: Optional[Path] = None,
) -> int:
    """Home directory management (stub).
    
    Args:
        mountpoint: Path to mounted rootfs
        partition: Partition path (unused)
    
    Returns:
        Exit code
    """
    log_section("Home Directory Management")
    log_warn("This feature is not yet implemented in Python version")
    log_warn("Use the bash rescue-helper.sh for home operations")
    return 1


# Register command
register_command(
    id="home",
    name="Home Directory Mgmt [UNTESTED]",
    number="11",
    handler=run,
    description="Backup/export home directories (not yet implemented)",
    tested=False,
)
