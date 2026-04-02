# system.py
#
# Purpose: System-level utilities and validation
#
# This module:
# - Checks for root privileges
# - Detects NixOS partitions on block devices
# - Provides system information helpers

from __future__ import annotations

import os
import re
import subprocess
from pathlib import Path
from typing import Optional

from lib.console import log_error, log_info


def ensure_root() -> None:
    """Exit if not running as root.
    
    Raises:
        SystemExit: If not root
    """
    if os.geteuid() != 0:
        log_error("This script must be run as root")
        log_info("Usage: sudo rescue-helper.py [partition]")
        raise SystemExit(1)


def get_partition_device(disk: str, partition_num: int) -> str:
    """Get partition device path from disk and partition number.
    
    Args:
        disk: Disk device path (e.g., /dev/sda)
        partition_num: Partition number
    
    Returns:
        Full partition device path
    """
    # Check if disk ends with a number (e.g., /dev/nvme0n1)
    if disk[-1].isdigit():
        return f"{disk}p{partition_num}"
    else:
        return f"{disk}{partition_num}"


def list_block_devices() -> list[str]:
    """List available block devices.
    
    Returns:
        List of device paths
    """
    try:
        result = subprocess.run(
            ["fdisk", "-l"],
            capture_output=True,
            text=True,
        )
        
        devices = []
        for line in result.stdout.split("\n"):
            match = re.match(r"^Disk (/dev/[^:]+):", line)
            if match:
                devices.append(match.group(1))
        
        return devices
    except subprocess.CalledProcessError:
        return []


def get_partition_label(partition: Path) -> Optional[str]:
    """Get partition label from lsblk.
    
    Args:
        partition: Path to partition device
    
    Returns:
        Partition label or None
    """
    try:
        result = subprocess.run(
            ["lsblk", "-no", "PARTLABEL", str(partition)],
            capture_output=True,
            text=True,
        )
        label = result.stdout.strip()
        return label if label else None
    except subprocess.CalledProcessError:
        return None


def detect_nixos_partition() -> Optional[Path]:
    """Auto-detect NixOS shimboot rootfs partition.
    
    Scans block devices for partitions labeled "shimboot_rootfs:*"
    and verifies they contain /nix and /etc/nixos.
    
    Returns:
        Path to detected partition, or None if not found
    """
    from lib.mounts import mounted
    
    devices = list_block_devices()
    
    for disk in devices:
        # Get partitions for this disk
        try:
            result = subprocess.run(
                ["fdisk", "-l", disk],
                capture_output=True,
                text=True,
            )
            
            for line in result.stdout.split("\n"):
                # Look for shimboot_rootfs partitions
                match = re.match(
                    r"^\s*(/dev/\S+).*shimboot_rootfs:(\S+)",
                    line,
                )
                if match:
                    partition = Path(match.group(1))
                    label = match.group(2)
                    
                    if label == "vendor":
                        continue
                    
                    # Quick check if it's a valid NixOS root
                    try:
                        with mounted(partition, Path("/tmp/rescue-check"), "ro") as mp:
                            nix_dir = mp / "nix"
                            nixos_dir = mp / "etc" / "nixos"
                            if nix_dir.exists() and nixos_dir.exists():
                                log_info(f"Found shimboot rootfs: {partition}")
                                return partition
                    except Exception:
                        continue
                        
        except subprocess.CalledProcessError:
            continue
    
    return None


def get_hostname_from_rootfs(mountpoint: Path) -> Optional[str]:
    """Read hostname from mounted rootfs.
    
    Args:
        mountpoint: Path to mounted rootfs
    
    Returns:
        Hostname or None
    """
    hostname_file = mountpoint / "etc" / "hostname"
    if hostname_file.exists():
        return hostname_file.read_text().strip()
    return None


def check_partition_exists(partition: Path) -> bool:
    """Check if partition device exists.
    
    Args:
        partition: Path to check
    
    Returns:
        True if device exists
    """
    return partition.exists() and partition.is_block_device()
