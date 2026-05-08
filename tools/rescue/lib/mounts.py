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

import os
import subprocess
from contextlib import contextmanager
from pathlib import Path
from typing import Generator, Optional

from lib.console import console, HAS_RICH, log_info, log_warn, log_success, log_error

# Find cryptsetup binary (available in nix develop, but may be missing outside)
_CRYPTSETUP_PATH: str | None = None

def _find_cryptsetup() -> str:
    """Locate cryptsetup binary, with NixOS fallback."""
    global _CRYPTSETUP_PATH
    if _CRYPTSETUP_PATH is not None:
        return _CRYPTSETUP_PATH
    # Check PATH first
    if subprocess.run(["which", "cryptsetup"], capture_output=True).returncode == 0:
        _CRYPTSETUP_PATH = "cryptsetup"
        return _CRYPTSETUP_PATH
    # NixOS system fallback
    nixos_paths = [
        Path("/run/current-system/sw/bin/cryptsetup"),
        Path("/nix/var/nix/profiles/system/sw/bin/cryptsetup"),
    ]
    for p in nixos_paths:
        if p.exists():
            _CRYPTSETUP_PATH = str(p)
            return _CRYPTSETUP_PATH
    raise MountError("cryptsetup not found. Run inside nix develop or install cryptsetup.")


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


def find_existing_mapper(partition: Path) -> Path | None:
    """Find an existing dm-crypt mapper that points to this partition.
    
    When the running system was booted from a LUKS device, the partition
    is already unlocked. Creating a second mapper to the same underlying
    device causes I/O conflicts. Reuse the existing mapper instead.
    
    Args:
        partition: Path to partition device (e.g. /dev/sdc5)
    
    Returns:
        Path to existing /dev/mapper device, or None if not found
    """
    slave_name = partition.name  # e.g. "sdc5"
    for dm_dir in Path("/sys/class/block").glob("dm-*"):
        slaves_dir = dm_dir / "slaves"
        if not slaves_dir.exists():
            continue
        for slave in slaves_dir.iterdir():
            if slave.name == slave_name:
                name_file = dm_dir / "dm" / "name"
                if name_file.exists():
                    mapper_name = name_file.read_text().strip()
                    return Path(f"/dev/mapper/{mapper_name}")
    return None


def is_luks_partition(partition: Path) -> bool:
    """Detect if a partition is LUKS-encrypted.
    
    Args:
        partition: Path to partition device
    
    Returns:
        True if LUKS header detected
    """
    try:
        subprocess.run(
            [_find_cryptsetup(), "luksDump", str(partition)],
            check=True,
            capture_output=True,
        )
        return True
    except subprocess.CalledProcessError:
        return False


def unlock_luks(partition: Path, mapper_name: str | None = None) -> Path:
    """Unlock a LUKS partition interactively.
    
    Prompts for passphrase up to 3 attempts.
    Uses a unique mapper name by default to avoid conflicts with udiskie
    or stale mappers from previous runs.
    
    Args:
        partition: Path to LUKS partition
        mapper_name: Name for /dev/mapper device (default: rescue-rootfs-PID)
    
    Returns:
        Path to mapper device
    
    Raises:
        MountError: If unlock fails after all attempts
    """
    if mapper_name is None:
        mapper_name = f"rescue-{os.getpid()}"
    
    target = partition
    keyfile = Path("/bootloader/opt/luks.key")
    
    # Try keyfile first
    if keyfile.exists():
        try:
            subprocess.run(
                [
                    _find_cryptsetup(), "open", "--allow-discards",
                    "--key-file", str(keyfile),
                    str(partition), mapper_name,
                ],
                check=True,
                capture_output=True,
            )
            log_info(f"LUKS: unlocked via keyfile → /dev/mapper/{mapper_name}")
            return Path(f"/dev/mapper/{mapper_name}")
        except subprocess.CalledProcessError:
            log_warn("LUKS: keyfile failed, falling back to passphrase")
    
    # Interactive passphrase
    for attempt in range(1, 4):
        console.print()
        if HAS_RICH:
            passphrase = console.input(
                f"Enter LUKS passphrase ({attempt}/3): ",
                password=True,
            )
        else:
            import getpass
            passphrase = getpass.getpass(
                f"Enter LUKS passphrase ({attempt}/3): "
            )
        try:
            proc = subprocess.Popen(
                [
                    _find_cryptsetup(), "open", "--allow-discards",
                    "--key-file", "-", str(partition), mapper_name,
                ],
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
            proc.communicate(input=passphrase.encode())
            if proc.returncode == 0:
                log_info(f"LUKS: unlocked via passphrase → /dev/mapper/{mapper_name}")
                return Path(f"/dev/mapper/{mapper_name}")
        except subprocess.CalledProcessError:
            pass
        log_error(f"LUKS: incorrect passphrase (attempt {attempt}/3)")
    
    raise MountError(f"Failed to unlock LUKS partition {partition}")


def close_luks(mapper_name: str) -> None:
    """Close a LUKS mapper device.
    
    Args:
        mapper_name: Name of /dev/mapper device to close
    """
    try:
        subprocess.run(
            [_find_cryptsetup(), "close", mapper_name],
            check=True,
            capture_output=True,
        )
        log_info(f"LUKS: closed /dev/mapper/{mapper_name}")
    except subprocess.CalledProcessError:
        pass


@contextmanager
def luks_mounted(
    partition: Path,
    mountpoint: Path,
    mode: str = "ro",
) -> Generator[Path, None, None]:
    """Context manager for mounting a partition, with automatic LUKS unlock.
    
    Detects LUKS encryption, prompts for passphrase if needed,
    unlocks the device, mounts it, and cleans up on exit.
    Uses a unique mapper name per invocation to avoid udiskie conflicts.
    Reuses existing mappers when the system is already booted from the device.
    
    Args:
        partition: Path to partition device
        mountpoint: Where to mount
        mode: "ro" for read-only, "rw" for read-write
    
    Yields:
        Path to mountpoint
    
    Raises:
        MountError: If unlock or mount fails
    """
    if not is_luks_partition(partition):
        with mounted(partition, mountpoint, mode) as mp:
            yield mp
        return
    
    # Check if partition is already unlocked (e.g. booted from this device)
    existing = find_existing_mapper(partition)
    if existing:
        log_info(f"LUKS: reusing existing mapper {existing}")
        with mounted(existing, mountpoint, mode) as mp:
            yield mp
        return
    
    mapper_name = f"rescue-{os.getpid()}"
    mapper = unlock_luks(partition, mapper_name)
    try:
        with mounted(mapper, mountpoint, mode) as mp:
            yield mp
    finally:
        close_luks(mapper_name)
        log_info("LUKS: mapper cleaned up")
