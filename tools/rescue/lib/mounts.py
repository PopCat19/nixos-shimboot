# mounts.py
#
# Purpose: Handle mount/unmount operations with automatic cleanup
#
# This module:
# - Provides context managers for safe mount/umount operations
# - Handles pre-existing mounts (udisks conflicts)
# - Ensures cleanup on errors, interrupts, or exceptions
# - Manages chroot filesystem bindings (dev, proc, sys, resolv.conf, etc)

from __future__ import annotations

import subprocess
from contextlib import contextmanager
from pathlib import Path
from typing import Generator, Optional

from lib.console import log_info, log_warn, log_success, log_error


class MountError(Exception):
    """Exception raised for mount operation failures."""
    pass


def find_existing_mounts(partition: Path) -> list[str]:
    """Find existing mount points for a partition.
    
    Args:
        partition: Path to partition device
    
    Returns:
        List of mount points
    """
    try:
        result = subprocess.run(
            ["lsblk", "-no", "MOUNTPOINT", str(partition)],
            capture_output=True,
            text=True,
        )
        mounts = [line.strip() for line in result.stdout.split("\n") if line.strip()]
        return mounts
    except subprocess.CalledProcessError:
        return []


def unmount_all(partition: Path) -> bool:
    """Unmount all mount points for a partition.
    
    Args:
        partition: Path to partition device
    
    Returns:
        True if lazy unmount initiated, False on critical error
    """
    mounts = find_existing_mounts(partition)
    
    if not mounts:
        return True
    
    log_warn(f"Device {partition} already mounted at:")
    for mp in mounts:
        log_info(f"  {mp}")
    
    for mp in mounts:
        log_info(f"Lazy unmounting {mp}...")
        # Use lazy unmount immediately - don't wait for busy resources
        subprocess.run(["umount", "-l", mp], check=False, capture_output=True)
    
    # Give it a moment to process
    import time
    time.sleep(0.5)
    
    # Check if still mounted (may still show in lsblk briefly)
    remaining = find_existing_mounts(partition)
    if remaining:
        # Try one more time with lazy unmount
        for mp in remaining:
            subprocess.run(["umount", "-l", mp], check=False, capture_output=True)
        time.sleep(0.5)
        
        # Check again - if still mounted, warn but don't fail
        # The lazy unmount will complete in background
        remaining = find_existing_mounts(partition)
        if remaining:
            log_warn(f"Mounts still present (will unmount in background): {remaining}")
    
    log_success(f"Unmount initiated for {partition}")
    return True


@contextmanager
def mounted(
    partition: Path,
    mountpoint: Path,
    mode: str = "ro",
) -> Generator[Path, None, None]:
    """Context manager for mounting a partition.
    
    Automatically unmounts on exit (success or failure).
    Handles pre-existing mounts.
    
    Args:
        partition: Path to partition device
        mountpoint: Where to mount
        mode: "ro" for read-only, "rw" for read-write
    
    Yields:
        Path to mountpoint
    
    Raises:
        MountError: If mount fails
    """
    # Ensure mountpoint exists
    mountpoint.mkdir(parents=True, exist_ok=True)
    
    # Clear any existing mounts
    if not unmount_all(partition):
        raise MountError(f"Failed to clear existing mounts for {partition}")
    
    # Mount
    log_info(f"Mounting {partition} at {mountpoint} ({mode})")
    try:
        subprocess.run(
            ["mount", "-o", mode, str(partition), str(mountpoint)],
            check=True,
        )
    except subprocess.CalledProcessError as e:
        log_error(f"Failed to mount {partition}")
        log_info("")
        log_info("The device may already be mounted. Try running:")
        log_info(f"  sudo umount {partition}")
        log_info(f"  sudo umount -l {partition}  # if the above fails")
        log_info("")
        raise MountError(f"Mount failed: {e}")
    
    try:
        yield mountpoint
    finally:
        # Always unmount - use lazy unmount to avoid "target is busy"
        log_info(f"Unmounting {mountpoint}")
        try:
            subprocess.run(["umount", "-l", str(mountpoint)], check=False)
        except subprocess.CalledProcessError:
            pass


@contextmanager
def chroot_bindings(
    mountpoint: Path,
    bind_resolv: bool = True,
    bind_devpts: bool = True,
    bind_shm: bool = True,
) -> Generator[None, None, None]:
    """Context manager for chroot filesystem bindings.
    
    Binds essential filesystems for chroot operation and cleans up on exit.
    
    Args:
        mountpoint: Path to chroot root
        bind_resolv: Bind /etc/resolv.conf for DNS
        bind_devpts: Mount devpts for pseudoterminals
        bind_shm: Bind /dev/shm for shared memory
    
    Yields:
        None
    """
    mounts: list[tuple[str, Path]] = []
    
    try:
        # Bind /dev
        dev_path = mountpoint / "dev"
        dev_path.mkdir(parents=True, exist_ok=True)
        subprocess.run(["mount", "--bind", "/dev", str(dev_path)], check=True)
        mounts.append(("dev", dev_path))
        
        # Bind /proc
        proc_path = mountpoint / "proc"
        proc_path.mkdir(parents=True, exist_ok=True)
        subprocess.run(["mount", "--bind", "/proc", str(proc_path)], check=True)
        mounts.append(("proc", proc_path))
        
        # Bind /sys
        sys_path = mountpoint / "sys"
        sys_path.mkdir(parents=True, exist_ok=True)
        subprocess.run(["mount", "--bind", "/sys", str(sys_path)], check=True)
        mounts.append(("sys", sys_path))
        
        # Mount devpts if requested
        if bind_devpts:
            pts_path = mountpoint / "dev" / "pts"
            pts_path.mkdir(parents=True, exist_ok=True)
            try:
                subprocess.run(
                    ["mount", "-t", "devpts", "devpts", str(pts_path),
                     "-o", "newinstance,ptmxmode=0666"],
                    check=True,
                )
            except subprocess.CalledProcessError:
                # Fallback to simpler mount
                subprocess.run(
                    ["mount", "-t", "devpts", "devpts", str(pts_path)],
                    check=False,
                )
            mounts.append(("devpts", pts_path))
        
        # Bind /dev/shm if requested
        if bind_shm:
            shm_path = mountpoint / "dev" / "shm"
            shm_path.mkdir(parents=True, exist_ok=True)
            subprocess.run(["mount", "--bind", "/dev/shm", str(shm_path)], check=True)
            mounts.append(("shm", shm_path))
        
        # Bind resolv.conf if requested
        if bind_resolv:
            resolv_src = Path("/etc/resolv.conf")
            resolv_dst = mountpoint / "etc" / "resolv.conf"
            if resolv_src.exists():
                resolv_dst.parent.mkdir(parents=True, exist_ok=True)
                subprocess.run(
                    ["mount", "--bind", str(resolv_src), str(resolv_dst)],
                    check=True,
                )
                mounts.append(("resolv", resolv_dst))
        
        yield
        
    finally:
        # Cleanup in reverse order
        for name, path in reversed(mounts):
            try:
                subprocess.run(["umount", str(path)], check=False)
            except subprocess.CalledProcessError:
                pass  # Ignore errors during cleanup


def find_shell_path(mountpoint: Path) -> Optional[Path]:
    """Find available shell in chroot.
    
    Args:
        mountpoint: Path to chroot root
    
    Returns:
        Path to shell relative to chroot, or None if not found
    """
    candidates = [
        Path("bin/bash"),
        Path("usr/bin/bash"),
        Path("run/current-system/sw/bin/bash"),
        Path("bin/sh"),
        Path("usr/bin/sh"),
        Path("run/current-system/sw/bin/sh"),
    ]
    
    for candidate in candidates:
        full_path = mountpoint / candidate
        if full_path.exists():
            return candidate
    
    return None
