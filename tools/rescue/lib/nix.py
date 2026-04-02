# nix.py
#
# Purpose: NixOS-specific operations and helpers
#
# This module:
# - Manages NixOS generations (list, rollback, delete)
# - Finds nixos-config directories
# - Detects hostnames from flake.nix
# - Runs nixos-rebuild with proper environment

from __future__ import annotations

import re
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

from lib.console import log_info, log_warn, log_success


@dataclass
class Generation:
    """Represents a NixOS generation."""
    number: int
    version: str
    date: str
    time: str
    path: Path
    is_current: bool


def list_generations(mountpoint: Path) -> list[Generation]:
    """List all NixOS generations in a rootfs.
    
    Args:
        mountpoint: Path to mounted rootfs
    
    Returns:
        List of Generation objects, sorted newest first
    """
    profiles_dir = mountpoint / "nix" / "var" / "nix" / "profiles"
    
    if not profiles_dir.exists():
        return []
    
    # Find current generation
    current_gen_path: Optional[Path] = None
    system_link = profiles_dir / "system"
    if system_link.is_symlink():
        current_gen_path = system_link.resolve()
    
    generations = []
    
    # Find all generation links
    for link in profiles_dir.glob("system-*-link"):
        if not link.is_symlink():
            continue
        
        # Extract generation number
        match = re.match(r"system-(\d+)-link", link.name)
        if not match:
            continue
        
        gen_num = int(match.group(1))
        gen_path = link.resolve()
        
        # Get version
        version_file = gen_path / "nixos-version"
        version = version_file.read_text().strip() if version_file.exists() else "unknown"
        
        # Get date/time from symlink
        try:
            stat_result = link.lstat()
            from datetime import datetime
            mtime = datetime.fromtimestamp(stat_result.st_mtime)
            date_str = mtime.strftime("%Y-%m-%d")
            time_str = mtime.strftime("%H:%M:%S")
        except (OSError, ValueError):
            date_str = "unknown"
            time_str = "unknown"
        
        is_current = gen_path == current_gen_path
        
        generations.append(Generation(
            number=gen_num,
            version=version,
            date=date_str,
            time=time_str,
            path=gen_path,
            is_current=is_current,
        ))
    
    # Sort by number descending (newest first)
    generations.sort(key=lambda g: g.number, reverse=True)
    return generations


def find_nixos_configs(mountpoint: Path) -> list[Path]:
    """Find all nixos-config directories in rootfs.
    
    Searches /home/*/nixos-config, /root/nixos-config, /etc/nixos
    and returns valid configs (must have flake.nix and not be empty).
    
    Args:
        mountpoint: Path to mounted rootfs
    
    Returns:
        List of valid config directory paths
    """
    configs = []
    
    # Search home directories
    home_dir = mountpoint / "home"
    if home_dir.exists():
        for user_dir in home_dir.iterdir():
            if user_dir.is_dir():
                config_dir = user_dir / "nixos-config"
                if is_valid_config(config_dir):
                    configs.append(config_dir)
    
    # Search /root
    root_config = mountpoint / "root" / "nixos-config"
    if is_valid_config(root_config):
        configs.append(root_config)
    
    # Search /etc/nixos
    etc_config = mountpoint / "etc" / "nixos"
    if is_valid_config(etc_config):
        configs.append(etc_config)
    
    return configs


def is_valid_config(config_dir: Path) -> bool:
    """Check if directory is a valid nixos-config.
    
    Must:
    - Exist
    - Have flake.nix
    - Not be empty (has files)
    
    Args:
        config_dir: Path to check
    
    Returns:
        True if valid config
    """
    if not config_dir.exists() or not config_dir.is_dir():
        return False
    
    flake_file = config_dir / "flake.nix"
    if not flake_file.exists():
        return False
    
    # Check if directory has files
    try:
        files = list(config_dir.rglob("*"))
        if len(files) <= 1:  # Only flake.nix
            return False
    except (OSError, PermissionError):
        return False
    
    return True


def get_flake_hostnames(config_dir: Path) -> list[str]:
    """Extract nixosConfigurations hostnames from flake.nix.
    
    Args:
        config_dir: Path to config directory
    
    Returns:
        List of hostname strings
    """
    flake_file = config_dir / "flake.nix"
    if not flake_file.exists():
        return []
    
    try:
        content = flake_file.read_text()
        # Match nixosConfigurations.<hostname> = 
        pattern = r"nixosConfigurations\.\s*(\w+)\s*="
        matches = re.findall(pattern, content)
        return sorted(set(matches))
    except (OSError, IOError):
        return []


def infer_hostname_from_path(config_dir: Path) -> Optional[str]:
    """Infer hostname from config directory path.
    
    e.g., /home/nixos-user/nixos-config -> nixos-user
    
    Args:
        config_dir: Path to config directory
    
    Returns:
        Inferred hostname or None
    """
    # Match /home/<user>/nixos-config pattern
    match = re.search(r"/home/([^/]+)/nixos-config$", str(config_dir))
    if match:
        return match.group(1)
    return None


def run_nixos_rebuild(
    config_dir: Path,
    hostname: str,
    chroot: Optional[Path] = None,
    mode: str = "boot",
) -> int:
    """Run nixos-rebuild with proper environment.
    
    Args:
        config_dir: Path to config (absolute, or relative to chroot)
        hostname: Hostname to build
        chroot: If set, run in chroot at this path
        mode: Rebuild mode (boot, switch, test, build)
    
    Returns:
        Exit code from nixos-rebuild
    """
    flake_ref = f"{config_dir}#{hostname}"
    
    cmd = [
        "nixos-rebuild",
        mode,
        "--flake", flake_ref,
        "--option", "sandbox", "false",
    ]
    
    env = {
        "PATH": "/nix/var/nix/profiles/system/sw/bin:/nix/var/nix/profiles/system/sw/sbin:/usr/bin:/bin",
        "NIX_PATH": "nixpkgs=/nix/var/nix/profiles/per-user/root/channels/nixos:nixos-config=/etc/nixos/configuration.nix:/nix/var/nix/profiles/per-user/root/channels",
    }
    
    if chroot:
        # Run in chroot
        cmd = ["chroot", str(chroot)] + cmd
        from lib.console import stream_command
        return stream_command(cmd, env=env)
    else:
        # Run directly
        from lib.console import stream_command
        return stream_command(cmd, env=env)
