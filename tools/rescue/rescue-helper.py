#!/usr/bin/env python3
# rescue-helper.py
#
# Purpose: Main TUI entry point for rescue operations
#
# This module:
# - Parses command line arguments
# - Detects or validates target partition
# - Mounts rootfs and maintains mount state
# - Displays fuzzy-searchable command menu
# - Dispatches to command modules

from __future__ import annotations

import argparse
import sys
from pathlib import Path
from typing import Optional

# Import lib modules
from lib.console import console, log_section, log_info, log_error, HAS_RICH
from lib.mounts import mounted
from lib.system import ensure_root, detect_nixos_partition, check_partition_exists

# Import commands (this registers them)
from commands import COMMANDS, filter_commands, get_command_by_number
from commands import (
    rebuild_nixos,
    chroot_shell,
    show_configs,
    git_pull_rebuild,
    remount,
    disk_usage,
    fs_check,
    generation_mgmt,
    bootloader_tools,
    home_mgmt,
    activation_script,
)


def create_menu_table(
    commands: list,
    target: Path,
    mountpoint: Path,
    mounted: bool,
    filter_query: str = "",
):
    """Create the command menu table.
    
    Args:
        commands: List of commands to show
        target: Target partition
        mountpoint: Current mountpoint
        mounted: Whether mounted
        filter_query: Current filter query
    
    Returns:
        Table or string representation
    """
    status = "(rw)" if mounted else "(ro)"
    title = f"NixOS Shimboot Rescue Helper"
    subtitle = f"Target: {target}  |  Mount: {mountpoint} {status}"
    
    if HAS_RICH:
        from rich.table import Table
        table = Table(
            title=f"{title}\n{subtitle}",
            show_header=False,
            box=None,
        )
        
        if filter_query:
            table.add_row(f"[dim]Filter: {filter_query}[/dim]")
            table.add_row("")
        
        for cmd in commands:
            marker = "→ " if cmd.number == "1" else "  "
            tested_marker = "" if cmd.tested else " [yellow][UNTESTED][/yellow]"
            table.add_row(f"{marker}[{cmd.number}] {cmd.name}{tested_marker}")
        
        table.add_row("")
        table.add_row("  [0] Exit")
        
        return table
    else:
        # Simple text fallback
        lines = [
            "",
            "=" * 50,
            f"  {title}",
            f"  {subtitle}",
            "=" * 50,
        ]
        
        if filter_query:
            lines.append(f"  Filter: {filter_query}")
            lines.append("")
        
        for cmd in commands:
            marker = "-> " if cmd.number == "1" else "   "
            tested_marker = "" if cmd.tested else " [UNTESTED]"
            lines.append(f"{marker}[{cmd.number}] {cmd.name}{tested_marker}")
        
        lines.append("")
        lines.append("   [0] Exit")
        lines.append("=" * 50)
        
        return "\n".join(lines)


def main_menu(
    mountpoint: Path,
    partition: Path,
    mounted_rw: bool,
) -> int:
    """Display main menu with fuzzy search.
    
    Args:
        mountpoint: Current mountpoint
        partition: Target partition
        mounted_rw: Whether mounted read-write
    
    Returns:
        Exit code when user exits
    """
    while True:
        # Get filter query
        console.print()
        query = console.input("Filter (Enter for all): ").strip().lower()
        
        # Filter commands
        if query:
            visible_commands = filter_commands(query)
        else:
            visible_commands = COMMANDS
        
        # Show menu
        console.print()
        table = create_menu_table(
            visible_commands,
            partition,
            mountpoint,
            mounted_rw,
            query,
        )
        console.print(table)
        
        # Get selection
        console.print()
        selection = console.input("Select: ").strip()
        
        if selection == "0":
            log_info("Goodbye!")
            return 0
        
        # Try to find command
        cmd = None
        
        # First try by number
        cmd = get_command_by_number(selection)
        
        # Then try by ID/name
        if not cmd and selection:
            matches = filter_commands(selection)
            if len(matches) == 1:
                cmd = matches[0]
            elif len(matches) > 1:
                log_error(f"Ambiguous: {selection} matches multiple commands")
                continue
        
        if cmd:
            # Execute command
            try:
                exit_code = cmd.handler(
                    mountpoint=mountpoint,
                    partition=partition,
                )
                
                # Update mount state if remount command
                if cmd.id in ("remount-rw", "remount-ro"):
                    # Will be detected on next loop iteration
                    pass
                    
            except Exception as e:
                log_error(f"Command failed: {e}")
        else:
            log_error(f"Unknown command: {selection}")


def main() -> int:
    """Main entry point.
    
    Returns:
        Exit code (0 = success)
    """
    parser = argparse.ArgumentParser(
        description="NixOS Shimboot Rescue Helper",
    )
    parser.add_argument(
        "partition",
        nargs="?",
        help="Target partition (e.g., /dev/sdc5)",
    )
    args = parser.parse_args()
    
    # Ensure root
    ensure_root()
    
    # Determine target partition
    if args.partition:
        partition = Path(args.partition)
        if not check_partition_exists(partition):
            log_error(f"Partition does not exist: {partition}")
            return 1
    else:
        # Auto-detect
        partition = detect_nixos_partition()
        if not partition:
            log_error("Could not auto-detect NixOS partition")
            log_info("Specify partition manually: sudo rescue-helper.py /dev/sdX5")
            return 1
    
    log_section("Rescue Environment Ready")
    log_info(f"Target partition: {partition}")
    
    # Mount and run menu
    mountpoint = Path("/mnt/nixos-rescue")
    
    try:
        with mounted(partition, mountpoint, "ro") as mp:
            return main_menu(mp, partition, mounted_rw=False)
    except Exception as e:
        log_error(f"Rescue helper failed: {e}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
