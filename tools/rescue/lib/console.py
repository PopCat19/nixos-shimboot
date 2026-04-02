# console.py
#
# Purpose: Provide colored output, tables, and live display
#
# This module:
# - Uses Rich if available, falls back to ANSI escape codes
# - Provides logging functions (info, warn, error, success)
# - Offers Live display for streaming command output
# - Handles panel and table creation for menus

from __future__ import annotations

import sys
from pathlib import Path
from typing import Optional

# Try to import Rich, fall back to basic implementation
try:
    from rich.console import Console
    from rich.live import Live
    from rich.panel import Panel
    from rich.table import Table
    from rich.text import Text
    HAS_RICH = True
except ImportError:
    HAS_RICH = False

# ANSI color codes for fallback
ANSI_CLEAR = '\033[0m'
ANSI_BOLD = '\033[1m'
ANSI_GREEN = '\033[1;32m'
ANSI_BLUE = '\033[1;34m'
ANSI_YELLOW = '\033[1;33m'
ANSI_RED = '\033[1;31m'
ANSI_CYAN = '\033[1;36m'

if HAS_RICH:
    # Global console instance
    console = Console()
else:
    # Simple fallback console
    class SimpleConsole:
        def print(self, *args, **kwargs):
            print(*args)
        
        def input(self, prompt: str = "") -> str:
            return input(prompt)
    
    console = SimpleConsole()


def _colorize(text: str, color: str) -> str:
    """Apply ANSI color if Rich not available."""
    if HAS_RICH:
        return text
    return f"{color}{text}{ANSI_CLEAR}"


def log_step(step: str, message: str) -> None:
    """Log a step header with blue bold styling."""
    if HAS_RICH:
        console.print(f"[bold blue][{step}][/bold blue] {message}")
    else:
        print(f"{_colorize('[' + step + ']', ANSI_BLUE)} {message}")


def log_info(message: str) -> None:
    """Log informational message with green indicator."""
    if HAS_RICH:
        console.print(f"[green]  > {message}[/green]")
    else:
        print(f"{_colorize('  >', ANSI_GREEN)} {message}")


def log_warn(message: str) -> None:
    """Log warning message with yellow styling."""
    if HAS_RICH:
        console.print(f"[yellow]  WARN {message}[/yellow]")
    else:
        print(f"{_colorize('  WARN', ANSI_YELLOW)} {message}")


def log_error(message: str) -> None:
    """Log error message with red styling."""
    if HAS_RICH:
        console.print(f"[red]  X {message}[/red]")
    else:
        print(f"{_colorize('  X', ANSI_RED)} {message}")


def log_success(message: str) -> None:
    """Log success message with green styling."""
    if HAS_RICH:
        console.print(f"[green]  OK {message}[/green]")
    else:
        print(f"{_colorize('  OK', ANSI_GREEN)} {message}")


def log_section(title: str) -> None:
    """Print a section header with cyan styling."""
    if HAS_RICH:
        console.print(f"\n[bold cyan]─── {title} ───[/bold cyan]\n")
    else:
        print(f"\n{_colorize('─── ' + title + ' ───', ANSI_CYAN)}\n")


def confirm_action(prompt: str = "Confirm action") -> bool:
    """Ask user for confirmation, returns True if confirmed."""
    response = console.input(f"> {prompt}? [y/N]: ").lower().strip()
    return response == "y"


# Fallback Table class for non-Rich environments
if not HAS_RICH:
    class SimpleTable:
        def __init__(self, **kwargs):
            self.title = kwargs.get('title', '')
            self.rows = []
        
        def add_column(self, *args, **kwargs):
            pass
        
        def add_row(self, *cells):
            self.rows.append(cells)
        
        def __str__(self):
            lines = []
            if self.title:
                lines.append(self.title)
                lines.append("=" * len(self.title))
            for row in self.rows:
                lines.append("  ".join(str(c) for c in row if c))
            return "\n".join(lines)


def create_menu_table(
    title: str,
    commands: list[tuple[str, str, str]],
    target: str,
    mountpoint: str,
    mounted: bool,
):
    """Create a menu table.
    
    Args:
        title: Menu title
        commands: List of (number, label, shortcut) tuples
        target: Target partition path
        mountpoint: Current mountpoint
        mounted: Whether filesystem is mounted
    
    Returns:
        Table object (Rich or simple)
    """
    if HAS_RICH:
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
    else:
        # Simple fallback
        table = SimpleTable(title=title)
        status = "(rw)" if mounted else "(not mounted)"
        table.add_row(f"Target: {target}  |  Mount: {mountpoint} {status}")
        table.add_row("")
        for num, label, shortcut in commands:
            marker = "→ " if num == "1" else "  "
            table.add_row(f"{marker}[{num}] {label}")
        return table


def stream_command(
    cmd: list[str],
    cwd: Optional[Path] = None,
    env: Optional[dict[str, str]] = None,
) -> int:
    """Stream command output.
    
    Args:
        cmd: Command and arguments as list
        cwd: Working directory for command
        env: Environment variables to set
    
    Returns:
        Command exit code
    """
    import subprocess
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
    
    if HAS_RICH:
        # Use Rich Live display
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
    else:
        # Simple fallback - just stream to stdout
        if process.stdout:
            for line in process.stdout:
                print(line, end='')
    
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
    
    if HAS_RICH:
        console.print(Panel("\n".join(lines), title="Configuration"))
    else:
        print(f"\n{_colorize('Configuration', ANSI_BOLD)}")
        print("-" * 40)
        for line in lines:
            print(f"  {line}")
        print()
