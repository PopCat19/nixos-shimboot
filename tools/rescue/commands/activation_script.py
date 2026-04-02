# activation_script.py
#
# Purpose: Stage-2 activation script [UNTESTED]
#
# This module:
# - Views activation script
# - Edits activation script

from __future__ import annotations

from pathlib import Path
from typing import Optional

from lib.console import log_warn, log_section
from commands import register_command


def run(
    mountpoint: Path,
    partition: Optional[Path] = None,
) -> int:
    """Activation script tools (stub).
    
    Args:
        mountpoint: Path to mounted rootfs
        partition: Partition path (unused)
    
    Returns:
        Exit code
    """
    log_section("Stage-2 Activation Script")
    log_warn("This feature is not yet implemented in Python version")
    log_warn("Use the bash rescue-helper.sh for activation script operations")
    return 1


# Register command
register_command(
    id="activation",
    name="Activation Script [UNTESTED]",
    number="12",
    handler=run,
    description="View/edit activation script (not yet implemented)",
    tested=False,
)
