# fix_perms.py
#
# Purpose: Fix file permissions in NixOS config directories
#
# This module:
# - Detects users in /home and /root
# - Chowns files to appropriate user
# - Makes tools/ scripts executable
# - Fixes git ownership after root operations

from __future__ import annotations

import subprocess
from pathlib import Path
from typing import Optional

from lib.console import console, log_info, log_warn, log_error, log_success, log_section, confirm_action
from lib.nix import find_nixos_configs
from commands import register_command


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


def get_uid_gid(username: str, mountpoint: Path) -> Optional[tuple[int, int]]:
    """Get UID and GID for a user from /etc/passwd in chroot.
    
    Args:
        username: Username to look up
        mountpoint: Path to mounted rootfs
    
    Returns:
        Tuple of (uid, gid) or None if not found
    """
    passwd_file = mountpoint / "etc" / "passwd"
    if not passwd_file.exists():
        return None
    
    try:
        for line in passwd_file.read_text().split("\n"):
            parts = line.split(":")
            if len(parts) >= 3 and parts[0] == username:
                uid = int(parts[2])
                gid = int(parts[3])
                return (uid, gid)
    except (ValueError, IndexError):
        pass
    
    return None


def fix_config_permissions(config_dir: Path, username: str, uid: int, gid: int) -> bool:
    """Fix permissions on a config directory.
    
    Args:
        config_dir: Path to NixOS config
        username: Target username
        uid: Target UID
        gid: Target GID
    
    Returns:
        True if successful
    """
    log_info(f"Fixing permissions on {config_dir}")
    log_info(f"  Owner: {username} (uid={uid}, gid={gid})")
    
    try:
        # Chown the entire directory recursively
        result = subprocess.run(
            ["chown", "-R", f"{uid}:{gid}", str(config_dir)],
            capture_output=True,
            text=True,
            check=False,
        )
        
        if result.returncode != 0:
            log_error(f"chown failed: {result.stderr}")
            return False
        
        # Find and make scripts executable in various directories
        exec_dirs = [
            ("tools", ["*.sh", "*.py"]),
            ("fish_functions", ["*.fish"]),
            ("helpers", ["*.sh", "*.py"]),
        ]
        
        for dir_name, patterns in exec_dirs:
            dir_path = config_dir / dir_name
            if dir_path.exists():
                for pattern in patterns:
                    for script in dir_path.rglob(pattern):
                        if script.is_file():
                            script.chmod(0o755)
                            log_info(f"  Made executable: {script.relative_to(config_dir)}")
        
        # Also check for scripts in the root of config
        for script in config_dir.glob("*.sh"):
            if script.is_file():
                script.chmod(0o755)
                log_info(f"  Made executable: {script.name}")
        
        log_success(f"Permissions fixed for {config_dir}")
        return True
        
    except Exception as e:
        log_error(f"Failed to fix permissions: {e}")
        return False


def run(
    mountpoint: Path,
    partition: Optional[Path] = None,
) -> int:
    """Fix permissions on NixOS config directories.
    
    Args:
        mountpoint: Path to mounted rootfs
        partition: Partition path (unused)
    
    Returns:
        Exit code (0 = success)
    """
    log_section("Fix Permissions")
    
    # Find all configs
    configs = find_nixos_configs(mountpoint)
    
    if not configs:
        log_error("No NixOS config directories found")
        return 1
    
    log_info(f"Found {len(configs)} config(s)")
    for cfg in configs:
        log_info(f"  - {cfg}")
    
    # Get users
    users = get_home_users(mountpoint)
    
    if not users:
        log_error("No users found in /home or /root")
        return 1
    
    console.print()
    log_info("Available users:")
    for i, (username, home_path) in enumerate(users, 1):
        log_info(f"  [{i}] {username} ({home_path})")
    
    console.print()
    choice = console.input("Select user to own configs (0 to skip): ").strip()
    
    if choice == "0" or not choice.isdigit():
        log_info("Skipped")
        return 0
    
    idx = int(choice) - 1
    if idx < 0 or idx >= len(users):
        log_error("Invalid selection")
        return 1
    
    username, _ = users[idx]
    
    # Get UID/GID from passwd
    uid_gid = get_uid_gid(username, mountpoint)
    if not uid_gid:
        log_error(f"Could not determine UID/GID for {username}")
        return 1
    
    uid, gid = uid_gid
    
    # Fix permissions for each config
    fixed_count = 0
    for config_dir in configs:
        console.print()
        if confirm_action(f"Fix permissions for {config_dir}?"):
            if fix_config_permissions(config_dir, username, uid, gid):
                fixed_count += 1
    
    console.print()
    log_success(f"Fixed permissions on {fixed_count} config(s)")
    log_info("Git ownership issues should now be resolved")
    
    return 0


# Register command
register_command(
    id="fix-perms",
    name="Fix config permissions",
    number="13",
    handler=run,
    description="Fix ownership and permissions on NixOS config directories",
    tested=True,
)
