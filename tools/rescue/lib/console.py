# console.py
#
# Purpose: Provide Rich-based colored output, tables, and live display
#
# This module:
# - Configures Rich console with consistent styling
# - Provides logging functions (info, warn, error, success)
# - Offers Live display for streaming command output
# - Handles panel and table creation for menus

from __future__ import annotations

import sys
from pathlib import Path
from typing import Optional

from rich.console import Console
from rich.live import Live
from rich.panel import Panel
from rich.table import Table
from rich.text import Text

# Global console instance
console = Console()


def log_step(step: str, message: str) -> None:
    """Log a step header with blue bold styling."""
    console.print(f"[bold blue][{step}][/bold blue] {message}")


def log_info(message: str) -> None:
    """Log informational message with green indicator."""
    console.print(f"[green]  > {message}[/green]")


def log_warn(message: str) -> None:
    """Log warning message with yellow styling."""
    console.print(f"[yellow]  WARN {message}[/yellow]")


def log_error(message: str) -> None:
    """Log error message with red styling."""
    console.print(f"[red]  X {message}[/red]")


def log_success(message: str) -> None:
    """Log success message with green styling."""
    console.print(f"[green]  OK {message}[/green]")


def log_section(title: str) -> None:
    """Print a section header with cyan styling."""
    console.print(f"\n[bold cyan]─── {title} ───[/bold cyan]\n")


def confirm_action(prompt: str = "Confirm action") -> bool:
    """Ask user for confirmation, returns True if confirmed."""
    response = console.input(f"> {prompt}? [y/N]: ").lower().strip()
    return response == "y"


def create_menu_table(
    title: str,
    commands: list[tuple[str, str, str]],
    target: str,
    mountpoint: str,
    mounted: bool,
) -> Table:
    """Create a Rich table for the command menu.
    
    Args:
        title: Menu title
        commands: List of (number, label, shortcut) tuples
        target: Target partition path
        mountpoint: Current mountpoint
        mounted: Whether filesystem is mounted
    
    Returns:
        Rich Table object
    """
    table = Table(
        title=title,
        show_header=False,
        show_edge=True,
        box=None,
    )
    
    # Add status row
    status = "(rw)" if mounted else "(not mounted)"
    table.add_row(f"Target: {target}  |  Mount: {mountpoint} {status}")
    table.add_row("")
    
    # Add commands
    for num, label, shortcut in commands:
        marker = "→ " if num == "1" else "  "
        table.add_row(f"{marker}[{num}] {label}")
    
    return table


def stream_command(
    cmd: list[str],
    cwd: Optional[Path] = None,
    env: Optional[dict[str, str]] = None,
) -> int:
    """Stream command output via Rich Live display.
    
    Args:
        cmd: Command and arguments as list
        cwd: Working directory for command
        env: Environment variables to set
    
    Returns:
        Command exit code
    """
    import subprocess
    import select
    import os
    
    # Create subprocess
    process = subprocess.Popen(
        cmd,
        cwd=cwd,
        env={**os.environ, **(env or {})},
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
    )
    
    output_lines: list[str] = []
    
    with Live(auto_refresh=False) as live:
        while True:
            if process.poll() is not None:
                break
            
            # Read available output
            if process.stdout:
                line = process.stdout.readline()
                if line:
                    output_lines.append(line.rstrip())
                    # Keep last 50 lines
                    if len(output_lines) > 50:
                        output_lines = output_lines[-50:]
                    
                    live.update(Text("\n".join(output_lines)))
                    live.refresh()
    
    # Get final exit code
    return process.wait()


def print_config_info(
    config_dir: Path,
    chroot_path: str,
    hostname: str,
    git_branch: Optional[str] = None,
    git_commit: Optional[str] = None,
) -> None:
    """Print configuration info panel."""
    lines = [
        f"Config: {config_dir}",
        f"Chroot: {chroot_path}",
        f"Hostname: {hostname}",
    ]
    
    if git_branch and git_commit:
        lines.append(f"Git: {git_branch} @ {git_commit}")
    
    console.print(Panel("\n".join(lines), title="Configuration"))
