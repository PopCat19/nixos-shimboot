# git_pull_rebuild.py
#
# Purpose: Git pull with various strategies then rebuild
#
# This module:
# - Shows git status
# - Offers pull strategies (simple, stash, merge)
# - Rebuilds after successful pull
# - Supports running git as the file owner to avoid permission issues
#
# Warning: Git runs as root in chroot by default. Operating on /home repos may
# change file ownership to root. Use run-as-user option to avoid this.

from __future__ import annotations

import subprocess
from pathlib import Path
from typing import Optional

from lib.console import (
    console, log_info, log_warn, log_error, log_success,
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


def get_file_owner(path: Path) -> Optional[str]:
    """Get the owner of a file/directory.
    
    Args:
        path: Path to check
    
    Returns:
        Username or None
    """
    try:
        result = subprocess.run(
            ["stat", "-c", "%U", str(path)],
            capture_output=True,
            text=True,
            check=True,
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError:
        return None


def get_home_users(mountpoint: Path) -> list[tuple[str, Path]]:
    """Get list of users with home directories.
    
    Args:
        mountpoint: Path to mounted rootfs
    
    Returns:
        List of (username, home_path) tuples
    """
    users = []
    
    # Check /home/* users
    home_dir = mountpoint / "home"
    if home_dir.exists():
        for user_dir in home_dir.iterdir():
            if user_dir.is_dir():
                users.append((user_dir.name, user_dir))
    
    # Check /root
    root_dir = mountpoint / "root"
    if root_dir.exists():
        users.append(("root", root_dir))
    
    return users


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
    
    # Check if filesystem is read-only and remount if needed
    test_file = mountpoint / ".write_test"
    try:
        test_file.touch()
        test_file.unlink()
    except (OSError, PermissionError):
        log_warn("Filesystem is read-only, attempting to remount...")
        if partition:
            try:
                import subprocess
                subprocess.run(["umount", str(mountpoint)], check=False)
                subprocess.run(
                    ["mount", "-o", "rw", str(partition), str(mountpoint)],
                    check=True,
                )
                log_success("Remounted read-write")
            except subprocess.CalledProcessError as e:
                log_error(f"Failed to remount: {e}")
                log_info("Use 'Remount read-write' option first")
                return 1
        else:
            log_error("Cannot remount - no partition specified")
            log_info("Use 'Remount read-write' option first")
            return 1
    
    # Find configs with git repos
    configs = find_nixos_configs(mountpoint)
    git_configs = [c for c in configs if get_git_info(c)]
    
    if not git_configs:
        log_error("No nixos-config with git repository found")
        return 1
    
    config_dir = git_configs[0]  # Use first git config
    
    # Determine if we should run as a specific user
    run_as_user: Optional[str] = None
    config_owner = get_file_owner(config_dir)
    
    # Check if config is in /home
    is_in_home = str(config_dir).startswith(str(mountpoint / "home"))
    
    if is_in_home and config_owner:
        console.print()
        log_warn("Config is in /home directory")
        log_info(f"Current owner: {config_owner}")
        log_info("Running git as root may cause permission issues")
        console.print()
        
        # Show available users
        users = get_home_users(mountpoint)
        if users:
            log_info("Available users:")
            for i, (username, _) in enumerate(users, 1):
                marker = " (current owner)" if username == config_owner else ""
                console.print(f"  [{i}] {username}{marker}")
            console.print(f"  [r] Run as root (not recommended)")
            console.print(f"  [Enter] Use '{config_owner}' (recommended)")
            console.print()
            
            choice = console.input("Select user to run git as: ").strip()
            
            if choice == "r":
                run_as_user = None
                log_warn("Running as root - files may get root ownership")
            elif choice.isdigit():
                idx = int(choice) - 1
                if 0 <= idx < len(users):
                    run_as_user = users[idx][0]
                    log_info(f"Will run git as: {run_as_user}")
                else:
                    run_as_user = config_owner
                    log_info(f"Invalid selection, using: {run_as_user}")
            elif choice == "":
                run_as_user = config_owner
                log_info(f"Will run git as: {run_as_user}")
            else:
                run_as_user = config_owner
                log_info(f"Invalid input, using: {run_as_user}")
        else:
            log_warn("Could not determine available users")
    
    # Get git info for display
    info = get_git_info(config_dir, run_as_user)
    
    # Show current state
    console.print()
    console.print(f"[bold]Config:[/bold] {config_dir}")
    if info:
        console.print(f"[bold]Branch:[/bold] {info.branch} @ {info.commit}")
        if run_as_user:
            console.print(f"[bold]Running as:[/bold] {run_as_user}")
    console.print()
    
    # Show status
    status = git_status_short(config_dir, run_as_user)
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
        success, output = git_pull(config_dir, run_as_user)
    elif choice == "2":
        success, output = git_stash_and_pull(config_dir, run_as_user)
    elif choice == "3":
        success, output = git_pull_merge(config_dir, run_as_user)
    else:
        log_error("Invalid choice")
        return 1
    
    if not success:
        console.print(output)
        return 1
    
    # Show new state
    new_info = get_git_info(config_dir, run_as_user)
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
