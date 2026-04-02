# show_configs.py
#
# Purpose: Display available nixos-config directories
#
# This module:
# - Lists all found nixos-config directories
# - Shows git branch, commit, and last message for each
# - Marks the currently selected config

from __future__ import annotations

from pathlib import Path
from typing import Optional

from lib.console import console, log_info, log_section, HAS_RICH
from lib.nix import find_nixos_configs
from lib.git_ops import get_git_info
from commands import register_command


def run(
    mountpoint: Path,
    partition: Optional[Path] = None,
    selected: Optional[Path] = None,
) -> int:
    """Show available configs.
    
    Args:
        mountpoint: Path to mounted rootfs
        partition: Partition path (unused)
        selected: Currently selected config (for marking)
    
    Returns:
        Exit code (0 = success)
    """
    log_section("Available Configurations")
    
    configs = find_nixos_configs(mountpoint)
    
    if not configs:
        log_info("No nixos-config directories found")
        return 0
    
    if HAS_RICH:
        from rich.table import Table
        table = Table(show_header=True, header_style="bold")
        table.add_column("#", style="cyan", no_wrap=True)
        table.add_column("Path", style="green")
        table.add_column("Git", style="blue")
        table.add_column("Last Commit", style="dim")
        
        for i, config in enumerate(configs, 1):
            marker = "→ " if config == selected else "  "
            
            # Get git info
            info = get_git_info(config)
            if info:
                git_str = f"{info.branch} @ {info.commit}"
                commit_str = info.message[:50]
            else:
                git_str = "no git"
                commit_str = ""
            
            table.add_row(
                f"{marker}{i}",
                str(config),
                git_str,
                commit_str,
            )
        
        console.print(table)
    else:
        # Simple fallback
        for i, config in enumerate(configs, 1):
            marker = "→ " if config == selected else "  "
            print(f"\n{marker}[{i}] {config}")
            
            # Get git info
            info = get_git_info(config)
            if info:
                print(f"    Git: {info.branch} @ {info.commit}")
                print(f"    Last: {info.message[:50]}")
            else:
                print("    (no git)")
    
    return 0


# Register command
register_command(
    id="configs",
    name="Show available configs",
    number="3",
    handler=run,
    description="List all nixos-config directories with git info",
    tested=True,
)
