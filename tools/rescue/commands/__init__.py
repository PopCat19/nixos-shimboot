# commands/__init__.py

from typing import Callable, Optional
from pathlib import Path
from dataclasses import dataclass


@dataclass
class Command:
    """Represents a rescue command."""
    id: str                    # Short identifier (for filtering)
    name: str                  # Display name
    number: str                # Menu number
    handler: Callable          # Function to call
    description: str = ""      # Optional longer description
    tested: bool = True        # Whether command is tested/working


# Registry of all commands
COMMANDS: list[Command] = []


def register_command(
    id: str,
    name: str,
    number: str,
    handler: Callable,
    description: str = "",
    tested: bool = True,
) -> Command:
    """Register a command."""
    cmd = Command(
        id=id,
        name=name,
        number=number,
        handler=handler,
        description=description,
        tested=tested,
    )
    COMMANDS.append(cmd)
    return cmd


def get_command_by_number(number: str) -> Optional[Command]:
    """Get command by its menu number."""
    for cmd in COMMANDS:
        if cmd.number == number:
            return cmd
    return None


def filter_commands(query: str) -> list[Command]:
    """Filter commands by search query."""
    query = query.lower()
    return [
        cmd for cmd in COMMANDS
        if query in cmd.id.lower()
        or query in cmd.name.lower()
        or query in cmd.number
    ]
