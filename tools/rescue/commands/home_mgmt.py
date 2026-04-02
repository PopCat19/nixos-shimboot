# home_mgmt.py
#
# Purpose: Home directory backup/export/import
#
# This module:
# - Exports home directories to compressed archives
# - Imports home from archives
# - Lists home contents
# - Views backup archives

from __future__ import annotations

import subprocess
from datetime import datetime
from pathlib import Path
from typing import Optional

from lib.console import console, log_info, log_warn, log_error, log_success, log_section, confirm_action
from commands import register_command


DEFAULT_BACKUP_DIR = Path("/tmp/home-backups")\n
def cmd_list_home(mountpoint: Path) -> int:
    """List home directory contents."""
    log_section("Home Directory Contents")
    
    home_dir = mountpoint / "home"
    if not home_dir.exists():
        log_warn("No /home directory found")
        return 1
    
    log_info("Users in /home:")
    try:
        for user_dir in sorted(home_dir.iterdir()):
            if user_dir.is_dir():
                print(f"  {user_dir.name}")
    except Exception as e:
        log_error(f"Failed to list home: {e}")
        return 1
    
    username = console.input("\nEnter username to inspect (or Enter to skip): ").strip()
    
    if username:
        user_home = home_dir / username
        if user_home.exists():
            log_info(f"Contents of /home/{username}:")
            try:
                subprocess.run(
                    ["du", "-h", "--max-depth=1", str(user_home)],
                    check=False,
                )
            except Exception as e:
                log_error(f"Failed to list contents: {e}")
        else:
            log_error(f"User home not found: {username}")
    
    return 0


def cmd_export(mountpoint: Path) -> int:
    """Export home directory to archive."""
    log_section("Export Home Directory")
    
    home_dir = mountpoint / "home"
    if not home_dir.exists():
        log_warn("No /home directory found")
        return 1
    
    # Show available users
    log_info("Available users:")
    users = [d.name for d in home_dir.iterdir() if d.is_dir()]
    for user in users:
        print(f"  - {user}")
    
    username = console.input("\nEnter username to export: ").strip()
    
    if not username:
        log_info("Cancelled")
        return 0
    
    user_home = home_dir / username
    if not user_home.exists():
        log_error(f"User home not found: {username}")
        return 1
    
    # Setup backup directory
    backup_dir = DEFAULT_BACKUP_DIR
    backup_dir.mkdir(exist_ok=True)
    
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    archive_name = f"{username}_home_{timestamp}.tar.zst"
    archive_path = backup_dir / archive_name
    
    log_info(f"Exporting to: {archive_path}")
    
    # Create metadata
    meta_content = f"""User: {username}
Exported: {datetime.now().isoformat()}
Source: {user_home}
"""
    
    try:
        # Create archive with zstd compression
        # First create tar, then compress with zstd
        tar_cmd = [
            "tar", "-C", str(home_dir), "-cf", "-", username
        ]
        zstd_cmd = ["zstd", "-T0", "-19", "-o", str(archive_path)]
        
        tar_proc = subprocess.Popen(tar_cmd, stdout=subprocess.PIPE)
        zstd_proc = subprocess.Popen(zstd_cmd, stdin=tar_proc.stdout)
        tar_proc.stdout.close()
        zstd_proc.wait()
        
        if zstd_proc.returncode == 0:
            # Get archive size
            size = archive_path.stat().st_size
            log_success(f"Exported: {archive_path} ({size} bytes)")
        else:
            log_error("Export failed")
            return 1
            
    except Exception as e:
        log_error(f"Export failed: {e}")
        return 1
    
    return 0


def cmd_import(mountpoint: Path) -> int:
    """Import home directory from archive."""
    log_section("Import Home Directory")
    
    backup_dir = DEFAULT_BACKUP_DIR
    
    # List available archives
    archives = list(backup_dir.glob("*_home_*.tar.zst"))
    
    if archives:
        log_info("Available archives:")
        for i, archive in enumerate(archives, 1):
            size = archive.stat().st_size
            print(f"  [{i}] {archive.name} ({size} bytes)")
    else:
        log_info("No archives in default location")
    
    # Allow custom path
    custom = console.input("\nEnter archive path (or number from list): ").strip()
    
    if not custom:
        log_info("Cancelled")
        return 0
    
    # Check if it's a number
    if custom.isdigit() and archives:
        idx = int(custom) - 1
        if 0 <= idx < len(archives):
            archive_path = archives[idx]
        else:
            log_error("Invalid selection")
            return 1
    else:
        archive_path = Path(custom)
    
    if not archive_path.exists():
        log_error(f"Archive not found: {archive_path}")
        return 1
    
    log_warn("This will overwrite existing home directory contents!")
    
    if not confirm_action("Proceed with import"):
        log_info("Import cancelled")
        return 0
    
    # Extract archive
    log_info(f"Importing from {archive_path}...")
    
    try:
        home_dir = mountpoint / "home"
        
        # Decompress and extract
        zstd_cmd = ["zstd", "-d", "-c", str(archive_path)]
        tar_cmd = ["tar", "-C", str(home_dir), "-xf", "-"]
        
        zstd_proc = subprocess.Popen(zstd_cmd, stdout=subprocess.PIPE)
        tar_proc = subprocess.Popen(tar_cmd, stdin=zstd_proc.stdout)
        zstd_proc.stdout.close()
        tar_proc.wait()
        
        if tar_proc.returncode == 0:
            log_success("Import complete")
        else:
            log_error("Import failed")
            return 1
            
    except Exception as e:
        log_error(f"Import failed: {e}")
        return 1
    
    return 0


def cmd_view_archives() -> int:
    """View backup archives."""
    log_section("Backup Archives")
    
    backup_dir = DEFAULT_BACKUP_DIR
    archives = list(backup_dir.glob("*.tar.zst"))
    
    if not archives:
        log_info("No backup archives found")
        log_info(f"Backup directory: {backup_dir}")
        return 0
    
    log_info(f"Archives in {backup_dir}:")
    for archive in sorted(archives):
        size = archive.stat().st_size
        mtime = datetime.fromtimestamp(archive.stat().st_mtime)
        print(f"  {archive.name:<40} {size:>10} bytes  ({mtime.strftime('%Y-%m-%d %H:%M')})")
    
    return 0


def run(
    mountpoint: Path,
    partition: Optional[Path] = None,
) -> int:
    """Home management menu."""
    while True:
        log_section("Home Directory Management")
        
        print("  [1] List home contents")
        print("  [2] Export home to archive")
        print("  [3] Import home from archive")
        print("  [4] View backup archives")
        print("  [0] Back to main menu")
        console.print()
        
        choice = console.input("Select: ").strip()
        
        if choice == "0":
            return 0
        elif choice == "1":
            cmd_list_home(mountpoint)
        elif choice == "2":
            cmd_export(mountpoint)
        elif choice == "3":
            cmd_import(mountpoint)
        elif choice == "4":
            cmd_view_archives()
        else:
            log_error("Invalid choice")


# Register command
register_command(
    id="home",
    name="Home Directory Mgmt",
    number="11",
    handler=run,
    description="Backup/export/import home directories",
    tested=False,  # [untested]
)
