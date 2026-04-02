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
import subprocess
import sys
from pathlib import Path
from typing import Optional

# Import lib modules
from lib.console import console, log_section, log_info, log_error, log_success, HAS_RICH
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
            # Don't add [UNTESTED] if already in name
            tested_marker = ""
            if not cmd.tested and "[UNTESTED]" not in cmd.name:
                tested_marker = " [yellow][UNTESTED][/yellow]"
            table.add_row(f"  [{cmd.number}] {cmd.name}{tested_marker}")
        
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
            tested_marker = ""
            if not cmd.tested and "[UNTESTED]" not in cmd.name:
                tested_marker = " [UNTESTED]"
            lines.append(f"   [{cmd.number}] {cmd.name}{tested_marker}")
        
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
        query = console.input("Filter (Enter for all, '..' to clear): ").strip().lower()
        
        # Handle special query to return/clear filter
        if query == "..":
            query = ""
        
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
        prompt = "Select (0=exit, ..=back" + (", enter=filter): " if query else "): ")
        selection = console.input(prompt).strip()
        
        # Handle special selections
        if selection == "0":
            log_info("Goodbye!")
            return 0
        elif selection == "..":
            continue  # Return to filter prompt
        elif selection == "" and query:
            continue  # Empty selection with filter = go back to filter prompt
        
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


def list_available_devices() -> list[tuple[str, str, str]]:
    """List available block devices with their info.
    
    Returns:
        List of (device_path, size, model) tuples
    """
    devices = []
    
    try:
        # List block devices
        result = subprocess.run(
            ["lsblk", "-o", "NAME,SIZE,TYPE,MODEL", "-d", "-n"],
            capture_output=True,
            text=True,
            check=False,
        )
        
        for line in result.stdout.strip().split("\n"):
            parts = line.split(maxsplit=3)
            if len(parts) >= 3:
                name = parts[0]
                size = parts[1]
                dev_type = parts[2]
                model = parts[3] if len(parts) > 3 else "Unknown"
                
                if dev_type == "disk":
                    devices.append((f"/dev/{name}", size, model))
    except Exception:
        pass
    
    return devices


def show_partitions(device: str) -> list[tuple[str, str, str]]:
    """Show partitions for a device.
    
    Args:
        device: Device path (e.g., /dev/sdc)
    
    Returns:
        List of (partition_path, size, partlabel) tuples
    """
    partitions = []
    
    try:
        result = subprocess.run(
            ["lsblk", "-o", "NAME,SIZE,PARTLABEL", "-n", device],
            capture_output=True,
            text=True,
            check=False,
        )
        
        for line in result.stdout.strip().split("\n")[1:]:  # Skip device itself
            parts = line.split(maxsplit=2)
            if len(parts) >= 2:
                name = parts[0]
                size = parts[1]
                label = parts[2] if len(parts) > 2 else ""
                partitions.append((f"/dev/{name}", size, label))
    except Exception:
        pass
    
    return partitions


def device_discovery() -> Optional[Path]:
    """Interactive device discovery.
    
    Returns:
        Selected partition path or None
    """
    log_section("Device Discovery")
    log_info("No partition specified and auto-detection failed.")
    log_info("Let's find your shimboot device...\n")
    
    # List available devices
    devices = list_available_devices()
    
    if not devices:
        log_error("No block devices found")
        return None
    
    print("Available devices:")
    for i, (dev, size, model) in enumerate(devices, 1):
        print(f"  [{i}] {dev:<12} {size:<8} {model}")
    print("  [0] Cancel")
    console.print()
    
    choice = console.input("Select device number: ").strip()
    
    if choice == "0" or not choice.isdigit():
        return None
    
    idx = int(choice) - 1
    if idx < 0 or idx >= len(devices):
        log_error("Invalid selection")
        return None
    
    selected_device = devices[idx][0]
    
    # Show partitions
    partitions = show_partitions(selected_device)
    
    if not partitions:
        log_error("No partitions found on device")
        return None
    
    console.print()
    print(f"Partitions on {selected_device}:")
    for i, (part, size, label) in enumerate(partitions, 1):
        marker = " <-- Likely shimboot" if "shimboot" in label.lower() or label == "nixos" else ""
        print(f"  [{i}] {part:<12} {size:<8} {label or 'no label'}{marker}")
    print("  [0] Cancel")
    console.print()
    
    part_choice = console.input("Select partition number: ").strip()
    
    if part_choice == "0" or not part_choice.isdigit():
        return None
    
    part_idx = int(part_choice) - 1
    if part_idx < 0 or part_idx >= len(partitions):
        log_error("Invalid selection")
        return None
    
    selected_partition = Path(partitions[part_idx][0])
    
    # Verify it exists
    if not selected_partition.exists():
        log_error(f"Partition does not exist: {selected_partition}")
        return None
    
    log_success(f"Selected: {selected_partition}")
    return selected_partition


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
            # Try device discovery
            partition = device_discovery()
            if not partition:
                log_error("No partition selected")
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
