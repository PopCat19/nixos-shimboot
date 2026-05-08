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


@contextmanager
def bootloader_mounted(partition: Path):
    """Mount the bootloader partition (p3) to a temp directory.
    
    Yields the mountpoint. Auto-unmounts on exit.
    Handles udiskie auto-mounts on p3.
    """
    bootloader_part = find_bootloader_partition(partition)
    if not bootloader_part or not bootloader_part.exists():
        raise RuntimeError(f"Bootloader partition not found for {partition}")
    
    temp_mount = Path("/tmp/bootloader-inspect")
    temp_mount.mkdir(parents=True, exist_ok=True)
    
    # Unmount any existing mounts on p3 (udiskie)
    try:
        result = subprocess.run(
            ["lsblk", "-no", "MOUNTPOINT", str(bootloader_part)],
            capture_output=True,
            text=True,
            check=False,
        )
        existing = [line.strip() for line in result.stdout.split("\n") if line.strip()]
        for mp in existing:
            subprocess.run(["umount", "-l", mp], check=False, capture_output=True)
    except Exception:
        pass
    
    subprocess.run(
        ["mount", "-o", "ro", str(bootloader_part), str(temp_mount)],
        check=True,
    )
    try:
        yield temp_mount
    finally:
        subprocess.run(["umount", "-l", str(temp_mount)], check=False)


def find_bootloader_dir(mountpoint: Path) -> Optional[Path]:
    """Find bootloader directory.
    
    For our architecture, bootloader lives in p3 (ext2), not inline.
    Returns None so callers use bootloader_mounted() instead.
    
    Args:
        mountpoint: Mounted rootfs (unused)
    
    Returns:
        None — bootloader is on separate p3 partition
    """
    return None


def cmd_list_layout(partition: Path) -> int:
    """List bootloader layout from p3."""
    log_section("Bootloader Layout")
    
    try:
        with bootloader_mounted(partition) as bootloader_dir:
            result = subprocess.run(
                ["find", str(bootloader_dir), "-maxdepth", "2", "-type", "f"],
                capture_output=True,
                text=True,
                check=False,
            )
            
            files = result.stdout.strip().split("\n")[:25]
            for f in files:
                if f:
                    rel = f.replace(str(bootloader_dir), "")
                    try:
                        stat = Path(f).stat()
                        size = stat.st_size
                        print(f"  {rel} ({size} bytes)")
                    except:
                        print(f"  {rel}")
    except Exception as e:
        log_error(f"Failed to list layout: {e}")
        return 1
    
    return 0


def cmd_view_bootstrap(partition: Path) -> int:
    """View bootstrap.sh from p3."""
    try:
        with bootloader_mounted(partition) as bootloader_dir:
            bootstrap = bootloader_dir / "bin" / "bootstrap.sh"
            if not bootstrap.exists():
                log_error("bootstrap.sh not found")
                return 1
            
            content = bootstrap.read_text()
            log_section("bootstrap.sh")
            
            lines = content.split("\n")[:100]
            for line in lines:
                print(line)
            
            if len(content.split("\n")) > 100:
                print(f"\n... ({len(content.split(chr(10))) - 100} more lines)")
    except Exception as e:
        log_error(f"Failed to read bootstrap.sh: {e}")
        return 1
    
    return 0


def cmd_edit_bootstrap(partition: Path) -> int:
    """Edit bootstrap.sh on the bootloader partition."""
    try:
        with bootloader_mounted(partition) as bootloader_dir:
            bootstrap = bootloader_dir / "bin" / "bootstrap.sh"
            if not bootstrap.exists():
                log_error("bootstrap.sh not found")
                return 1
            
            # Remount rw for editing
            subprocess.run(["mount", "-o", "remount,rw", str(bootloader_dir)], check=False)
            
            editor = console.input("Editor command (default: nano): ").strip() or "nano"
            subprocess.run([editor, str(bootstrap)], check=False)
            log_success("Edit complete")
    except Exception as e:
        log_error(f"Failed to edit: {e}")
        return 1
    
    return 0


def cmd_backup_restore(partition: Path) -> int:
    """Backup or restore bootloader from p3."""
    backup_dir = Path("/tmp/bootloader-backup")
    backup_dir.mkdir(exist_ok=True)
    
    log_section("Bootloader Backup/Restore")
    print(f"  [1] Create backup from p3")
    print(f"  [2] Restore to p3")
    print(f"  [0] Cancel")
    console.print()
    
    choice = console.input("Select: ").strip()
    
    if choice == "1":
        from datetime import datetime
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        backup_path = backup_dir / f"bootloader_backup_{timestamp}.tar.gz"
        
        log_info(f"Creating backup: {backup_path}")
        try:
            with bootloader_mounted(partition) as bootloader_dir:
                subprocess.run(
                    ["tar", "-czf", str(backup_path), "-C", str(bootloader_dir), "."],
                    check=True,
                )
            log_success(f"Backup created: {backup_path}")
        except Exception as e:
            log_error(f"Backup failed: {e}")
            return 1
    
    elif choice == "2":
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
        log_warn("This will overwrite bootloader files on p3!")
        
        if not confirm_action("Proceed with restore"):
            log_info("Restore cancelled")
            return 0
        
        try:
            with bootloader_mounted(partition) as bootloader_dir:
                subprocess.run(["mount", "-o", "remount,rw", str(bootloader_dir)], check=False)
                subprocess.run(
                    ["tar", "-xzf", str(selected), "-C", str(bootloader_dir)],
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


def cmd_sync_repo(partition: Path) -> int:
    """Sync bootloader from current repo into p3 partition.
    
    For rapid iteration on bootstrap.sh without full rebuild.
    """
    import os
    
    bootloader_part = find_bootloader_partition(partition)
    if not bootloader_part or not bootloader_part.exists():
        log_error(f"Bootloader partition not found: {bootloader_part}")
        return 1
    
    # Find repo bootloader directory
    repo_dir = Path(os.getcwd())
    repo_bootloader = repo_dir / "bootloader"
    if not (repo_bootloader / "bin" / "bootstrap.sh").exists():
        # Try parent dirs
        for parent in repo_dir.parents:
            candidate = parent / "bootloader" / "bin" / "bootstrap.sh"
            if candidate.exists():
                repo_bootloader = parent / "bootloader"
                break
    
    if not (repo_bootloader / "bin" / "bootstrap.sh").exists():
        log_error(f"Repo bootloader/ not found (cwd: {repo_dir})")
        return 1
    
    log_info(f"Bootloader partition: {bootloader_part}")
    log_info(f"Repo source: {repo_bootloader}")
    
    # Check for existing mounts on bootloader partition and clear them
    try:
        result = subprocess.run(
            ["lsblk", "-no", "MOUNTPOINT", str(bootloader_part)],
            capture_output=True,
            text=True,
            check=False,
        )
        existing_mps = [line.strip() for line in result.stdout.split("\n") if line.strip()]
        for mp in existing_mps:
            log_warn(f"Unmounting existing mount: {mp}")
            subprocess.run(["umount", "-l", mp], check=False, capture_output=True)
    except Exception:
        pass
    
    if not confirm_action("Sync repo bootloader into image"):
        log_info("Sync cancelled")
        return 0
    
    # Create full backup before any changes
    from datetime import datetime
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_path = Path("/tmp/bootloader-backup") / f"bootloader_backup_{timestamp}.tar.gz"
    backup_path.parent.mkdir(exist_ok=True)
    
    temp_mount = Path("/tmp/bootloader-sync")
    temp_mount.mkdir(parents=True, exist_ok=True)
    
    try:
        # Mount bootloader partition read-only first for backup
        subprocess.run(
            ["mount", "-o", "ro", str(bootloader_part), str(temp_mount)],
            check=True,
        )
        log_info(f"Backing up current bootloader → {backup_path}")
        subprocess.run(
            ["tar", "-czf", str(backup_path), "-C", str(temp_mount), "."],
            check=True,
        )
        log_success(f"Backup created: {backup_path}")
        subprocess.run(["umount", str(temp_mount)], check=False)
        
        # Now remount rw for sync
        subprocess.run(
            ["mount", "-o", "rw", str(bootloader_part), str(temp_mount)],
            check=True,
        )
        log_info(f"Mounted {bootloader_part} at {temp_mount} (rw)")
        
        # Also back up just bootstrap.sh for quick comparison
        existing = temp_mount / "bin" / "bootstrap.sh"
        if existing.exists():
            backup = temp_mount / "bin" / "bootstrap.sh.bak"
            subprocess.run(["cp", "-a", str(existing), str(backup)], check=False)
        
        # Sync repo files
        log_info("Syncing from repo ...")
        # Prefer rsync if available, fallback to cp -a
        if subprocess.run(["which", "rsync"], capture_output=True).returncode == 0:
            subprocess.run(
                ["rsync", "-a", "--delete",
                 str(repo_bootloader) + "/",
                 str(temp_mount) + "/"],
                check=True,
            )
        else:
            # Fallback: cp -a without delete
            subprocess.run(
                ["cp", "-a", str(repo_bootloader) + "/.", str(temp_mount) + "/"],
                check=True,
            )
        
        log_success("Bootloader synced")
        
        # Show what changed
        if existing.exists() and backup.exists():
            result = subprocess.run(
                ["diff", "-q", str(backup), str(existing)],
                capture_output=True,
            )
            if result.returncode == 0:
                log_info("bootstrap.sh unchanged")
            else:
                log_success("bootstrap.sh updated")
        
        log_info("")
        log_info("If the new bootloader fails, restore with:")
        log_info(f"  tar -xzf {backup_path} -C /tmp/bootloader-sync")
        log_info("Or use: [10] Bootloader Tools → [4] Restore from backup")
    except subprocess.CalledProcessError as e:
        log_error(f"Sync failed: {e}")
        return 1
    finally:
        log_info("Unmounting ...")
        subprocess.run(["umount", "-l", str(temp_mount)], check=False)
    
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
        print("  [7] Sync from repo (rapid iteration)")
        print("  [0] Back to main menu")
        console.print()
        
        choice = console.input("Select: ").strip()
        
        if choice == "0":
            return 0
        elif choice == "1":
            if partition:
                cmd_list_layout(partition)
            else:
                log_error("No partition specified")
        elif choice == "2":
            if partition:
                cmd_view_bootstrap(partition)
            else:
                log_error("No partition specified")
        elif choice == "3":
            if partition:
                cmd_edit_bootstrap(partition)
            else:
                log_error("No partition specified")
        elif choice == "4":
            if partition:
                cmd_backup_restore(partition)
            else:
                log_error("No partition specified")
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
        elif choice == "7":
            if partition:
                cmd_sync_repo(partition)
            else:
                log_error("No partition specified")
        else:
            log_error("Invalid choice")


# Register commands
register_command(
    id="bootloader",
    name="Bootloader Tools",
    number="10",
    handler=run,
    description="Inspect bootloader, view/edit bootstrap.sh, backup/restore",
    tested=False,  # [untested]
)

register_command(
    id="sync-bootloader",
    name="Sync Bootloader from Repo",
    number="14",
    handler=lambda mountpoint, partition: cmd_sync_repo(partition) if partition else 1,
    description="Rapidly sync repo bootloader/ into image p3 without rebuild",
    tested=False,  # [untested]
)
