# git_pull_rebuild.py
#
# Purpose: Git pull with various strategies then rebuild
#
# This module:
# - Shows git status
# - Offers pull strategies (simple, stash, merge)
# - Rebuilds after successful pull

from __future__ import annotations

from pathlib import Path
from typing import Optional

from lib.console import (
    console, log_info, log_warn, log_error, 
    log_section, confirm_action
)
from lib.git_ops import (
    get_git_info,
    git_status_short,
    git_pull,
    git_stash_and_pull,
    git_pull_merge,
)
from lib.nix import find_nixos_configs, is_valid_config
from commands import register_command


def run(
    mountpoint: Path,
    partition: Optional[Path] = None,
) -> int:
    """Git pull and rebuild.
    
    Args:
        mountpoint: Path to mounted rootfs
        partition: Partition path (unused)
    
    Returns:
        Exit code (0 = success)
    """
    log_section("Git Pull & Rebuild")
    
    # Find configs with git repos
    configs = find_nixos_configs(mountpoint)
    git_configs = [c for c in configs if get_git_info(c)]
    
    if not git_configs:
        log_error("No nixos-config with git repository found")
        return 1
    
    config_dir = git_configs[0]  # Use first git config
    
    # Show current state
    console.print(f"[bold]Config:[/bold] {config_dir}")
    console.print(f"[bold]Branch:[/bold] {info.branch} @ {info.commit}")
    console.print()
    
    # Show status
    status = git_status_short(config_dir)
    if status:
        log_warn("You have uncommitted changes:")
        console.print(status)
    else:
        log_info("Working directory clean")
    
    console.print()
    
    # Strategy selection
    strategies = [
        ("1", "Simple pull", "may fail if conflicts"),
        ("2", "Stash & pull", "saves changes, restores later"),
        ("3", "Auto-merge pull", "favors remote changes"),
        ("0", "Cancel", "abort operation"),
    ]
    
    for num, name, desc in strategies:
        console.print(f"  [{num}] {name:20} - {desc}")
    
    console.print()
    choice = console.input("Select strategy: ").strip()
    
    if choice == "0":
        log_info("Cancelled")
        return 0
    
    # Execute pull
    if choice == "1":
        success, output = git_pull(config_dir)
    elif choice == "2":
        success, output = git_stash_and_pull(config_dir)
    elif choice == "3":
        success, output = git_pull_merge(config_dir)
    else:
        log_error("Invalid choice")
        return 1
    
    if not success:
        console.print(output)
        return 1
    
    # Show new state
    new_info = get_git_info(config_dir)
    if new_info:
        log_info(f"Now at: {new_info.branch} @ {new_info.commit}")
    
    # Proceed to rebuild
    console.print()
    if confirm_action("Proceed to rebuild"):
        # Import and run rebuild
        from commands.rebuild_nixos import run as rebuild_run
        return rebuild_run(
            mountpoint=mountpoint,
            partition=partition,
            config_override=config_dir,
        )
    
    return 0


# Register command
register_command(
    id="git-rebuild",
    name="Git pull & rebuild",
    number="4",
    handler=run,
    description="Pull latest changes then rebuild NixOS",
    tested=True,
)
