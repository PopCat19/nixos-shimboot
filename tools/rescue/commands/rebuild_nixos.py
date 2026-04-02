# rebuild_nixos.py
#
# Purpose: Auto-detect and rebuild NixOS system
#
# This module:
# - Auto-detects nixos-config directories
# - Selects most recent git commit
# - Detects or infers hostname
# - Runs nixos-rebuild boot with proper environment

from __future__ import annotations

import sys
from pathlib import Path
from typing import Optional

from lib.console import (
    console, log_info, log_warn, log_error, log_success, 
    log_step, log_section, confirm_action, print_config_info
)
from lib.mounts import mounted, chroot_bindings
from lib.nix import (
    find_nixos_configs,
    get_flake_hostnames,
    infer_hostname_from_path,
    run_nixos_rebuild,
)
from lib.git_ops import get_git_info
from lib.system import get_hostname_from_rootfs
from commands import register_command


def select_best_config(
    mountpoint: Path,
    valid_configs: list[Path],
) -> Path:
    """Select best config based on git commit time.
    
    Args:
        mountpoint: Rootfs mountpoint
        valid_configs: List of valid config paths
    
    Returns:
        Best config path
    """
    from lib.git_ops import get_git_info
    
    if len(valid_configs) == 1:
        return valid_configs[0]
    
    # Find most recent git commit
    best_config = valid_configs[0]
    best_time = 0
    
    for config in valid_configs:
        info = get_git_info(config)
        if info:
            # Get commit timestamp
            import subprocess
            try:
                result = subprocess.run(
                    ["git", "-C", str(config), "log", "-1", "--format=%ct"],
                    capture_output=True,
                    text=True,
                    check=True,
                )
                commit_time = int(result.stdout.strip())
                if commit_time > best_time:
                    best_time = commit_time
                    best_config = config
            except (subprocess.CalledProcessError, ValueError):
                pass
    
    return best_config


def detect_hostname(
    config_dir: Path,
    mountpoint: Path,
) -> str:
    """Detect hostname from config and system.
    
    Args:
        config_dir: Path to nixos-config
        mountpoint: Rootfs mountpoint
    
    Returns:
        Hostname to use
    """
    # Get available hostnames from flake
    available = get_flake_hostnames(config_dir)
    
    # Infer from path
    inferred = infer_hostname_from_path(config_dir)
    
    # Get system hostname
    system_hostname = get_hostname_from_rootfs(mountpoint)
    
    if len(available) == 1:
        hostname = available[0]
        # Warn if mismatch
        if system_hostname and hostname != system_hostname:
            log_warn(f"Hostname mismatch!")
            log_warn(f"  /etc/hostname: {system_hostname}")
            log_warn(f"  flake.nix: {hostname}")
    elif len(available) > 1:
        # Try to match inferred or system hostname
        hostname = None
        if inferred and inferred in available:
            hostname = inferred
            log_info(f"Matched config directory to host: {inferred}")
        elif system_hostname and system_hostname in available:
            hostname = system_hostname
        
        if not hostname:
            hostname = available[0]
    else:
        # No hostnames in flake, use inferred
        hostname = inferred or "nixos"
        if inferred:
            log_warn(f"No hostname detected, using inferred: {inferred}")
    
    return hostname


def run(
    mountpoint: Path,
    partition: Optional[Path] = None,
    config_override: Optional[Path] = None,
    hostname_override: Optional[str] = None,
) -> int:
    """Execute rebuild command.
    
    Args:
        mountpoint: Path to mounted rootfs
        partition: Partition path (for info)
        config_override: Use specific config instead of auto-detect
        hostname_override: Use specific hostname instead of auto-detect
    
    Returns:
        Exit code (0 = success)
    """
    log_section("Rebuild NixOS System")
    
    # Find configs
    if config_override:
        config_dir = config_override
        log_info(f"Using specified config: {config_dir}")
    else:
        valid_configs = find_nixos_configs(mountpoint)
        
        if not valid_configs:
            log_error("No valid nixos-config found")
            log_info("Searched in /home/*/nixos-config, /root/nixos-config, /etc/nixos")
            return 1
        
        config_dir = select_best_config(mountpoint, valid_configs)
        log_info(f"Selected: {config_dir}")
    
    # Calculate chroot-relative path (must start with / for flake)
    config_chroot = "/" + str(config_dir.relative_to(mountpoint))
    
    # Detect hostname
    if hostname_override:
        hostname = hostname_override
    else:
        hostname = detect_hostname(config_dir, mountpoint)
    
    # Get git info
    git_info = get_git_info(config_dir)
    
    # Print config info
    print_config_info(
        config_dir=config_dir,
        chroot_path=config_chroot,
        hostname=hostname,
        git_branch=git_info.branch if git_info else None,
        git_commit=git_info.commit if git_info else None,
    )
    
    log_info("Will run: nixos-rebuild boot")
    log_info(f"  Flake: {config_chroot}#{hostname}")
    log_info("  Sandbox: disabled (required in chroot)")
    
    if not confirm_action("Proceed with rebuild"):
        log_info("Rebuild cancelled")
        return 0
    
    # Run rebuild in chroot with bindings
    log_step("Rebuild", "Starting nixos-rebuild...")
    
    try:
        with chroot_bindings(mountpoint):
            exit_code = run_nixos_rebuild(
                config_dir=Path(config_chroot),
                hostname=hostname,
                chroot=mountpoint,
                mode="boot",
            )
        
        if exit_code == 0:
            log_success("Rebuild completed successfully!")
        else:
            log_error(f"Rebuild failed with exit code {exit_code}")
        
        return exit_code
        
    except Exception as e:
        log_error(f"Rebuild failed: {e}")
        return 1


# Register command
register_command(
    id="rebuild",
    name="[GO] Rebuild NixOS",
    number="1",
    handler=run,
    description="Auto-detect config and rebuild NixOS system",
    tested=True,
)
