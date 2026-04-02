# activation_script.py
#
# Purpose: Stage-2 activation script management
#
# This module:
# - Views activation script from latest generation
# - Searches activation script
# - Edits activation script (advanced)

from __future__ import annotations

import subprocess
from pathlib import Path
from typing import Optional

from lib.console import console, log_info, log_warn, log_error, log_success, log_section, confirm_action
from lib.nix import list_generations
from commands import register_command


def find_latest_generation(mountpoint: Path) -> Optional[Path]:
    """Find path to latest generation.
    
    Args:
        mountpoint: Mounted rootfs
    
    Returns:
        Path to latest generation or None
    """
    generations = list_generations(mountpoint)
    if not generations:
        return None
    return generations[0].path


def cmd_view_script(mountpoint: Path) -> int:
    """View activation script."""
    log_section("Stage-2 Activation Script")
    
    latest = find_latest_generation(mountpoint)
    if not latest:
        log_error("No generations found")
        return 1
    
    activate_script = latest / "activate"
    if not activate_script.exists():
        log_error("Activation script not found")
        return 1
    
    log_info(f"Activation script: {activate_script}")
    log_info(f"Generation: {latest.name}")
    console.print()
    
    # Show first 100 lines
    try:
        content = activate_script.read_text()
        lines = content.split("\n")[:100]
        
        for line in lines:
            print(line)
        
        total_lines = len(content.split("\n"))
        if total_lines > 100:
            print(f"\n... ({total_lines - 100} more lines)")
    except Exception as e:
        log_error(f"Failed to read script: {e}")
        return 1
    
    return 0


def cmd_search_script(mountpoint: Path) -> int:
    """Search activation script."""
    log_section("Search Activation Script")
    
    latest = find_latest_generation(mountpoint)
    if not latest:
        log_error("No generations found")
        return 1
    
    activate_script = latest / "activate"
    if not activate_script.exists():
        log_error("Activation script not found")
        return 1
    
    pattern = console.input("Enter search pattern: ").strip()
    
    if not pattern:
        log_info("Cancelled")
        return 0
    
    try:
        result = subprocess.run(
            ["grep", "-n", pattern, str(activate_script)],
            capture_output=True,
            text=True,
            check=False,
        )
        
        if result.stdout:
            print(result.stdout)
        else:
            log_info("No matches found")
    except Exception as e:
        log_error(f"Search failed: {e}")
        return 1
    
    return 0


def cmd_edit_script(mountpoint: Path, partition: Optional[Path] = None) -> int:
    """Edit activation script (advanced)."""
    log_section("Edit Activation Script")
    
    latest = find_latest_generation(mountpoint)
    if not latest:
        log_error("No generations found")
        return 1
    
    activate_script = latest / "activate"
    if not activate_script.exists():
        log_error("Activation script not found")
        return 1
    
    log_warn("WARNING: Editing activation script is advanced!")
    log_warn("Changes affect system activation and may break boot.")
    
    if not confirm_action("Proceed with editing"):
        log_info("Edit cancelled")
        return 0
    
    # Remount rw if needed
    test_file = mountpoint / ".write_test"
    try:
        test_file.touch()
        test_file.unlink()
    except (OSError, PermissionError):
        if partition:
            log_info("Remounting read-write...")
            try:
                subprocess.run(["umount", str(mountpoint)], check=False)
                subprocess.run(
                    ["mount", "-o", "rw", str(partition), str(mountpoint)],
                    check=False,
                )
            except Exception as e:
                log_warn(f"Remount warning: {e}")
    
    editor = console.input("Editor command (default: nano): ").strip() or "nano"
    
    try:
        subprocess.run([editor, str(activate_script)], check=False)
        log_success("Edit complete")
    except Exception as e:
        log_error(f"Edit failed: {e}")
        return 1
    
    return 0


def run(
    mountpoint: Path,
    partition: Optional[Path] = None,
) -> int:
    """Activation script menu."""
    while True:
        log_section("Stage-2 Activation Script (Legacy)")
        
        print("  [1] View activation script")
        print("  [2] Search activation script")
        print("  [3] Edit activation script (advanced)")
        print("  [0] Back to main menu")
        console.print()
        
        choice = console.input("Select: ").strip()
        
        if choice == "0":
            return 0
        elif choice == "1":
            cmd_view_script(mountpoint)
        elif choice == "2":
            cmd_search_script(mountpoint)
        elif choice == "3":
            cmd_edit_script(mountpoint, partition)
        else:
            log_error("Invalid choice")


# Register command
register_command(
    id="activation",
    name="Activation Script",
    number="12",
    handler=run,
    description="View/edit stage-2 activation script (advanced)",
    tested=False,  # [untested]
)
