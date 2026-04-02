# generation_mgmt.py
#
# Purpose: NixOS generation management
#
# This module:
# - Lists all NixOS generations with details
# - Rolls back to a specific generation
# - Deletes old generations with garbage collection
# - Shows diff between generations

from __future__ import annotations

import subprocess
from pathlib import Path
from typing import Optional

from lib.console import console, log_info, log_warn, log_error, log_success, log_section, confirm_action
from lib.nix import list_generations
from commands import register_command


def cmd_list(mountpoint: Path) -> int:
    """List all generations."""
    generations = list_generations(mountpoint)
    
    if not generations:
        log_warn("No generations found")
        return 1
    
    log_section("NixOS Generations")
    
    # Header
    print(f"{'GEN':<4} {'DATE':<20} {'SIZE':<12} {'CURRENT':<10} PATH")
    print("-" * 80)
    
    for gen in generations:
        current_marker = "OK (active)" if gen.is_current else ""
        
        # Get size
        try:
            result = subprocess.run(
                ["du", "-sh", str(gen.path)],
                capture_output=True,
                text=True,
                check=False,
            )
            size = result.stdout.split()[0] if result.stdout else "?"
        except:
            size = "?"
        
        print(f"{gen.number:<4} {gen.date:<20} {size:<12} {current_marker:<10} {gen.path}")
    
    return 0


def cmd_rollback(mountpoint: Path) -> int:
    """Rollback to a specific generation."""
    # First list generations
    cmd_list(mountpoint)
    
    console.print()
    gen_num = console.input("Enter generation number to rollback to (or 'cancel'): ").strip()
    
    if gen_num.lower() == "cancel":
        log_info("Rollback cancelled")
        return 0
    
    if not gen_num.isdigit():
        log_error("Invalid generation number")
        return 1
    
    profile_dir = mountpoint / "nix" / "var" / "nix" / "profiles"
    target_gen = profile_dir / f"system-{gen_num}-link"
    
    if not target_gen.is_symlink():
        log_error(f"Generation {gen_num} not found")
        return 1
    
    # Resolve target
    try:
        target_path = target_gen.resolve()
    except (OSError, RuntimeError):
        log_error(f"Could not resolve generation {gen_num}")
        return 1
    
    log_warn(f"This will switch the system profile to generation {gen_num}")
    log_info(f"Target: {target_path}")
    
    if not confirm_action("Proceed with rollback"):
        log_info("Rollback cancelled")
        return 0
    
    # Perform rollback
    log_info(f"Rolling back to generation {gen_num}...")
    system_link = profile_dir / "system"
    
    try:
        system_link.unlink(missing_ok=True)
        system_link.symlink_to(target_path)
        log_success(f"Rolled back to generation {gen_num}")
        log_info("Reboot for changes to take effect")
        return 0
    except (OSError, PermissionError) as e:
        log_error(f"Failed to rollback: {e}")
        return 1


def cmd_delete(mountpoint: Path) -> int:
    """Delete old generations."""
    generations = list_generations(mountpoint)
    
    if not generations:
        log_warn("No generations found")
        return 1
    
    cmd_list(mountpoint)
    
    console.print()
    log_warn("WARNING: Deleting generations is irreversible!")
    keep_str = console.input("Keep last N generations (default: 3): ").strip()
    keep_count = int(keep_str) if keep_str.isdigit() else 3
    
    total_count = len(generations)
    delete_count = total_count - keep_count
    
    if delete_count <= 0:
        log_info(f"No generations to delete (total: {total_count}, keep: {keep_count})")
        return 0
    
    log_warn(f"Will delete {delete_count} generation(s), keeping newest {keep_count}")
    
    if not confirm_action("Proceed with deletion"):
        log_info("Deletion cancelled")
        return 0
    
    # Delete old generations (sorted oldest first)
    profile_dir = mountpoint / "nix" / "var" / "nix" / "profiles"
    deleted = 0
    
    for gen in sorted(generations, key=lambda g: g.number)[:delete_count]:
        gen_link = profile_dir / f"system-{gen.number}-link"
        try:
            gen_link.unlink()
            log_info(f"Deleted generation {gen.number}")
            deleted += 1
        except (OSError, PermissionError) as e:
            log_error(f"Failed to delete generation {gen.number}: {e}")
    
    log_success(f"Deleted {deleted} generation(s)")
    
    # Garbage collect
    log_info("Running garbage collection...")
    try:
        subprocess.run(
            ["nix", "store", "--store", str(mountpoint / "nix" / "store"), 
             "collect-garbage", "-d"],
            check=False,
            capture_output=True,
        )
    except Exception as e:
        log_warn(f"Garbage collection had issues: {e}")
    
    return 0


def cmd_diff(mountpoint: Path) -> int:
    """Show diff between two generations."""
    generations = list_generations(mountpoint)
    
    if len(generations) < 2:
        log_warn("Need at least 2 generations to compare")
        return 1
    
    cmd_list(mountpoint)
    
    console.print()
    gen1 = console.input("Enter first generation number: ").strip()
    gen2 = console.input("Enter second generation number: ").strip()
    
    if not gen1.isdigit() or not gen2.isdigit():
        log_error("Invalid generation number(s)")
        return 1
    
    profile_dir = mountpoint / "nix" / "var" / "nix" / "profiles"
    gen1_path = profile_dir / f"system-{gen1}-link"
    gen2_path = profile_dir / f"system-{gen2}-link"
    
    if not gen1_path.is_symlink() or not gen2_path.is_symlink():
        log_error("Invalid generation number(s)")
        return 1
    
    try:
        path1 = gen1_path.resolve()
        path2 = gen2_path.resolve()
    except (OSError, RuntimeError):
        log_error("Could not resolve generation paths")
        return 1
    
    log_info(f"Comparing generation {gen1} -> {gen2}...")
    
    try:
        subprocess.run(
            ["nix", "store", "--store", str(mountpoint / "nix" / "store"),
             "diff-closures", str(path1), str(path2)],
            check=False,
        )
    except Exception as e:
        log_error(f"Failed to show diff: {e}")
        return 1
    
    return 0


def run(
    mountpoint: Path,
    partition: Optional[Path] = None,
) -> int:
    """Generation management menu."""
    while True:
        log_section("Generation Management")
        
        print("  [1] List generations")
        print("  [2] Rollback generation")
        print("  [3] Delete old generations")
        print("  [4] View generation diff")
        print("  [0] Back to main menu")
        console.print()
        
        choice = console.input("Select: ").strip()
        
        if choice == "0":
            return 0
        elif choice == "1":
            cmd_list(mountpoint)
        elif choice == "2":
            cmd_rollback(mountpoint)
        elif choice == "3":
            cmd_delete(mountpoint)
        elif choice == "4":
            cmd_diff(mountpoint)
        else:
            log_error("Invalid choice")


# Register command
register_command(
    id="generations",
    name="Generation Management",
    number="9",
    handler=run,
    description="Manage NixOS generations (list, rollback, delete, diff)",
    tested=False,  # [untested] - user will test on another host
)
