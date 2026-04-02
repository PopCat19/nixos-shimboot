# bootloader_tools.py
#
# Purpose: Bootloader inspection and management
#
# This module:
# - Lists bootloader layout
# - Views bootstrap.sh
# - Backs up and restores bootloader
# - Inspects kernel/initramfs
# - Checks ChromeOS GPT flags

from __future__ import annotations

import subprocess
from pathlib import Path
from typing import Optional

from lib.console import console, log_info, log_warn, log_error, log_success, log_section, confirm_action
from commands import register_command


def find_bootloader_partition(partition: Path) -> Optional[Path]:
    """Find bootloader partition (usually partition 3).
    
    Args:
        partition: Rootfs partition path
    
    Returns:
        Path to bootloader partition or None
    """
    # Extract device and partition number
    device_str = str(partition)
    
    # Handle nvme devices (e.g., /dev/nvme0n1p5)
    if "nvme" in device_str:
        # Remove the partition number and add p3
        base = device_str.rsplit("p", 1)[0]
        return Path(f"{base}p3")
    else:
        # Standard devices (e.g., /dev/sdc5)
        base = device_str.rstrip("0123456789")
        return Path(f"{base}3")


def find_bootloader_dir(mountpoint: Path) -> Optional[Path]:
    """Find bootloader directory in rootfs or partition.
    
    Args:
        mountpoint: Mounted rootfs
    
    Returns:
        Path to bootloader directory or None
    """
    # Check inline bootloader first
    inline = mountpoint / "bootloader"
    if (inline / "bin" / "bootstrap.sh").exists():
        return inline
    
    # Otherwise need to mount partition 3
    return None


def cmd_list_layout(mountpoint: Path) -> int:
    """List bootloader layout."""
    bootloader_dir = find_bootloader_dir(mountpoint)
    
    if not bootloader_dir:
        log_error("Bootloader directory not found")
        return 1
    
    log_section("Bootloader Layout")
    
    try:
        result = subprocess.run(
            ["find", str(bootloader_dir), "-maxdepth", "2", "-type", "f"],
            capture_output=True,
            text=True,
            check=False,
        )
        
        files = result.stdout.strip().split("\n")[:25]
        for f in files:
            if f:
                try:
                    stat = Path(f).stat()
                    size = stat.st_size
                    print(f"  {f} ({size} bytes)")
                except:
                    print(f"  {f}")
    except Exception as e:
        log_error(f"Failed to list layout: {e}")
        return 1
    
    return 0


def cmd_view_bootstrap(mountpoint: Path) -> int:
    """View bootstrap.sh."""
    bootloader_dir = find_bootloader_dir(mountpoint)
    
    if not bootloader_dir:
        log_error("Bootloader directory not found")
        return 1
    
    bootstrap = bootloader_dir / "bin" / "bootstrap.sh"
    if not bootstrap.exists():
        log_error(f"bootstrap.sh not found in {bootloader_dir}/bin")
        return 1
    
    try:
        content = bootstrap.read_text()
        log_section("bootstrap.sh")
        
        # Show first 100 lines
        lines = content.split("\n")[:100]
        for line in lines:
            print(line)
        
        if len(content.split("\n")) > 100:
            print(f"\n... ({len(content.split(chr(10))) - 100} more lines)")
    except Exception as e:
        log_error(f"Failed to read bootstrap.sh: {e}")
        return 1
    
    return 0


def cmd_edit_bootstrap(mountpoint: Path, partition: Optional[Path] = None) -> int:
    """Edit bootstrap.sh."""
    bootloader_dir = find_bootloader_dir(mountpoint)
    
    if not bootloader_dir:
        log_error("Bootloader directory not found")
        return 1
    
    bootstrap = bootloader_dir / "bin" / "bootstrap.sh"
    if not bootstrap.exists():
        log_error(f"bootstrap.sh not found")
        return 1
    
    # Need to remount rw
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
        subprocess.run([editor, str(bootstrap)], check=False)
        log_success("Edit complete")
    except Exception as e:
        log_error(f"Failed to edit: {e}")
        return 1
    
    return 0


def cmd_backup_restore(mountpoint: Path) -> int:
    """Backup or restore bootloader."""
    bootloader_dir = find_bootloader_dir(mountpoint)
    
    if not bootloader_dir:
        log_error("Bootloader directory not found")
        return 1
    
    backup_dir = Path("/tmp/bootloader-backup")
    backup_dir.mkdir(exist_ok=True)
    
    log_section("Bootloader Backup/Restore")
    print(f"  [1] Create backup")
    print(f"  [2] Restore from backup")
    print(f"  [0] Cancel")
    console.print()
    
    choice = console.input("Select: ").strip()
    
    if choice == "1":
        # Create backup
        from datetime import datetime
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        backup_path = backup_dir / f"bootloader_backup_{timestamp}.tar.gz"
        
        log_info(f"Creating backup: {backup_path}")
        try:
            subprocess.run(
                ["tar", "-czf", str(backup_path), "-C", str(bootloader_dir.parent), 
                 bootloader_dir.name],
                check=True,
            )
            log_success(f"Backup created: {backup_path}")
        except Exception as e:
            log_error(f"Backup failed: {e}")
            return 1
    
    elif choice == "2":
        # List available backups
        backups = list(backup_dir.glob("bootloader_backup_*.tar.gz"))
        if not backups:
            log_warn("No backups found")
            return 1
        
        log_info("Available backups:")
        for i, backup in enumerate(backups, 1):
            print(f"  [{i}] {backup.name}")
        
        idx = console.input("Select backup number: ").strip()
        if not idx.isdigit() or int(idx) < 1 or int(idx) > len(backups):
            log_error("Invalid selection")
            return 1
        
        selected = backups[int(idx) - 1]
        log_warn("This will overwrite bootloader files!")
        
        if not confirm_action("Proceed with restore"):
            log_info("Restore cancelled")
            return 0
        
        try:
            subprocess.run(
                ["tar", "-xzf", str(selected), "-C", str(bootloader_dir.parent)],
                check=True,
            )
            log_success("Bootloader restored")
        except Exception as e:
            log_error(f"Restore failed: {e}")
            return 1
    
    return 0


def cmd_inspect_kernel(partition: Path) -> int:
    """Inspect kernel/initramfs."""
    # Find kernel partition (partition 2)
    device_str = str(partition)
    
    if "nvme" in device_str:
        base = device_str.rsplit("p", 1)[0]
        kernel_part = Path(f"{base}p2")
    else:
        base = device_str.rstrip("0123456789")
        kernel_part = Path(f"{base}2")
    
    log_section("Kernel/Initramfs Inspection")
    log_info(f"Kernel partition: {kernel_part}")
    
    try:
        # Get size
        result = subprocess.run(
            ["lsblk", "-no", "SIZE", str(kernel_part)],
            capture_output=True,
            text=True,
            check=False,
        )
        if result.stdout.strip():
            log_info(f"Size: {result.stdout.strip()}")
        
        # Get strings from first MB
        log_info("Kernel signature (first block strings):")
        result = subprocess.run(
            ["dd", f"if={kernel_part}", "bs=1M", "count=1", "status=none"],
            capture_output=True,
            check=False,
        )
        if result.stdout:
            strings_result = subprocess.run(
                ["strings"],
                input=result.stdout,
                capture_output=True,
                check=False,
            )
            lines = strings_result.stdout.decode().split("\n")[:10]
            for line in lines:
                if line:
                    print(f"  {line}")
    except Exception as e:
        log_warn(f"Kernel inspection limited: {e}")
    
    return 0


def cmd_check_gpt(partition: Path) -> int:
    """Check ChromeOS GPT flags."""
    log_section("ChromeOS GPT Flags")
    
    # Find parent disk
    try:
        result = subprocess.run(
            ["lsblk", "-no", "PKNAME", str(partition)],
            capture_output=True,
            text=True,
            check=False,
        )
        parent = result.stdout.strip()
        if not parent:
            log_warn("Could not determine parent disk")
            return 1
        
        disk_dev = Path(f"/dev/{parent}")
        
        if not subprocess.run(["which", "cgpt"], capture_output=True).returncode == 0:
            log_warn("cgpt not available")
            return 1
        
        log_info(f"Inspecting GPT of {disk_dev}")
        subprocess.run(["cgpt", "show", str(disk_dev)], check=False)
    except Exception as e:
        log_warn(f"GPT check failed: {e}")
        return 1
    
    return 0


def run(
    mountpoint: Path,
    partition: Optional[Path] = None,
) -> int:
    """Bootloader tools menu."""
    while True:
        log_section("Bootloader Tools")
        
        print("  [1] List bootloader layout")
        print("  [2] View bootstrap.sh")
        print("  [3] Edit bootstrap.sh")
        print("  [4] Backup or Restore bootloader")
        print("  [5] Inspect kernel/initramfs")
        print("  [6] Check ChromeOS GPT flags")
        print("  [0] Back to main menu")
        console.print()
        
        choice = console.input("Select: ").strip()
        
        if choice == "0":
            return 0
        elif choice == "1":
            cmd_list_layout(mountpoint)
        elif choice == "2":
            cmd_view_bootstrap(mountpoint)
        elif choice == "3":
            cmd_edit_bootstrap(mountpoint, partition)
        elif choice == "4":
            cmd_backup_restore(mountpoint)
        elif choice == "5":
            if partition:
                cmd_inspect_kernel(partition)
            else:
                log_error("No partition specified")
        elif choice == "6":
            if partition:
                cmd_check_gpt(partition)
            else:
                log_error("No partition specified")
        else:
            log_error("Invalid choice")


# Register command
register_command(
    id="bootloader",
    name="Bootloader Tools",
    number="10",
    handler=run,
    description="Inspect bootloader, view/edit bootstrap.sh, backup/restore",
    tested=False,  # [untested]
)
