# disk_usage.py
#
# Purpose: Check disk and directory usage
#
# This module:
# - Shows df output for mounted partition
# - Lists largest directories

from __future__ import annotations

import subprocess
from pathlib import Path
from typing import Optional

from lib.console import console, log_info, log_warn, log_section, confirm_action
from commands import register_command


def run(
    mountpoint: Path,
    partition: Optional[Path] = None,
) -> int:
    """Show disk usage.
    
    Args:
        mountpoint: Path to mounted rootfs
        partition: Partition path (for df)
    
    Returns:
        Exit code (0 = success)
    """
    log_section("Disk Usage")
    
    # Show df output
    if partition:
        log_info(f"Partition: {partition}")
        try:
            result = subprocess.run(
                ["df", "-h", str(partition)],
                capture_output=True,
                text=True,
                check=True,
            )
            console.print(result.stdout)
        except subprocess.CalledProcessError:
            pass
    
    # Show top directories
    console.print()
    log_warn("Scanning all directories may take a while on large filesystems")
    log_warn("This operation reads the entire directory tree and may wear NAND storage")
    
    if not confirm_action("Continue with directory scan"):
        log_info("Cancelled")
        return 0
    
    log_info("Scanning directories (Ctrl+C to cancel)...")
    
    try:
        result = subprocess.run(
            ["du", "-h", "--max-depth=1", str(mountpoint)],
            capture_output=True,
            text=True,
            check=True,
        )
        
        lines = result.stdout.strip().split("\n")
        lines.sort(key=lambda x: x.split()[0], reverse=True)
        
        for line in lines[:10]:
            console.print(f"  {line}")
    except subprocess.CalledProcessError:
        pass
    
    return 0


# Register command
register_command(
    id="disk-usage",
    name="Check disk usage",
    number="7",
    handler=run,
    description="Show disk usage and largest directories",
    tested=True,
)
