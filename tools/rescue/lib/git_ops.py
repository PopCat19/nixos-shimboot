# git_ops.py
#
# Purpose: Git operations for config management
#
# This module:
# - Provides safe git pull operations with conflict handling
# - Shows git status and branch info
# - Stashes changes when needed
# - Supports running git as a specific user via su
#
# Warning: This module can run git as root. When used in chroot on /home repos,
# file ownership may be changed to root, causing permission issues for users.
# Use run_as_user parameter to run git as the file owner instead.

from __future__ import annotations

import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

from lib.console import log_info, log_warn, log_success, log_error, log_step


def _build_git_cmd(repo_path: Path, git_args: list[str], run_as_user: Optional[str] = None) -> list[str]:
    """Build git command, optionally wrapped with su to run as specific user.
    
    Args:
        repo_path: Path to git repository
        git_args: Git command arguments
        run_as_user: Optional username to run git as
    
    Returns:
        Command list ready for subprocess
    """
    if run_as_user:
        # Use su to run as specific user
        # Need to cd to repo first since su doesn't preserve -C
        cmd = f"cd '{repo_path}' && git {' '.join(git_args)}"
        return ["su", "-c", cmd, run_as_user]
    else:
        return ["git", "-C", str(repo_path)] + git_args


@dataclass
class GitInfo:
    """Git repository information."""
    branch: str
    commit: str
    message: str
    has_changes: bool
    has_staged: bool


def get_git_info(repo_path: Path, run_as_user: Optional[str] = None) -> Optional[GitInfo]:
    """Get current git info for a repository.
    
    Args:
        repo_path: Path to git repository
        run_as_user: Optional username to run git as
    
    Returns:
        GitInfo object or None if not a git repo
    """
    git_dir = repo_path / ".git"
    if not git_dir.exists():
        return None
    
    try:
        # Get branch
        result = subprocess.run(
            _build_git_cmd(repo_path, ["rev-parse", "--abbrev-ref", "HEAD"], run_as_user),
            capture_output=True,
            text=True,
            check=True,
        )
        branch = result.stdout.strip()
        
        # Get commit hash
        result = subprocess.run(
            _build_git_cmd(repo_path, ["rev-parse", "--short", "HEAD"], run_as_user),
            capture_output=True,
            text=True,
            check=True,
        )
        commit = result.stdout.strip()
        
        # Get last commit message
        result = subprocess.run(
            _build_git_cmd(repo_path, ["log", "-1", "--format=%s"], run_as_user),
            capture_output=True,
            text=True,
            check=True,
        )
        message = result.stdout.strip()
        
        # Check for changes
        result = subprocess.run(
            _build_git_cmd(repo_path, ["diff", "--quiet", "HEAD"], run_as_user),
            capture_output=True,
        )
        has_changes = result.returncode != 0
        
        # Check for staged changes
        result = subprocess.run(
            _build_git_cmd(repo_path, ["diff", "--cached", "--quiet", "HEAD"], run_as_user),
            capture_output=True,
        )
        has_staged = result.returncode != 0
        
        return GitInfo(
            branch=branch,
            commit=commit,
            message=message,
            has_changes=has_changes,
            has_staged=has_staged,
        )
    except subprocess.CalledProcessError:
        return None


def git_status_short(repo_path: Path, run_as_user: Optional[str] = None) -> str:
    """Get short git status output.
    
    Args:
        repo_path: Path to git repository
        run_as_user: Optional username to run git as
    
    Returns:
        Status output as string
    """
    try:
        result = subprocess.run(
            _build_git_cmd(repo_path, ["status", "--short"], run_as_user),
            capture_output=True,
            text=True,
            check=True,
        )
        return result.stdout
    except subprocess.CalledProcessError:
        return ""


def git_pull(repo_path: Path, run_as_user: Optional[str] = None) -> tuple[bool, str]:
    """Simple git pull.
    
    Args:
        repo_path: Path to git repository
        run_as_user: Optional username to run git as
    
    Returns:
        Tuple of (success, output)
    """
    log_step("Git", "Pulling latest changes...")
    try:
        result = subprocess.run(
            _build_git_cmd(repo_path, ["pull"], run_as_user),
            capture_output=True,
            text=True,
            check=True,
        )
        log_success("Git pull successful")
        return True, result.stdout + result.stderr
    except subprocess.CalledProcessError as e:
        log_error("Git pull failed")
        return False, e.stdout + e.stderr


def git_stash_and_pull(repo_path: Path, run_as_user: Optional[str] = None) -> tuple[bool, str]:
    """Stash changes then pull.
    
    Args:
        repo_path: Path to git repository
        run_as_user: Optional username to run git as
    
    Returns:
        Tuple of (success, output)
    """
    import datetime
    
    log_step("Git", "Stashing local changes...")
    timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    
    try:
        # Stash
        result = subprocess.run(
            _build_git_cmd(repo_path, ["stash", "push", "-m", f"rescue-helper auto-stash {timestamp}"], run_as_user),
            capture_output=True,
            text=True,
            check=True,
        )
        log_success("Changes stashed")
        
        # Pull
        log_step("Git", "Pulling latest changes...")
        result = subprocess.run(
            _build_git_cmd(repo_path, ["pull"], run_as_user),
            capture_output=True,
            text=True,
            check=True,
        )
        log_success("Git pull successful")
        log_info("Your stashed changes are saved. Run 'git stash pop' to restore them.")
        return True, result.stdout + result.stderr
        
    except subprocess.CalledProcessError as e:
        log_error("Git operation failed")
        return False, e.stdout + e.stderr


def git_pull_merge(repo_path: Path, run_as_user: Optional[str] = None) -> tuple[bool, str]:
    """Pull with auto-merge strategy (theirs).
    
    Args:
        repo_path: Path to git repository
        run_as_user: Optional username to run git as
    
    Returns:
        Tuple of (success, output)
    """
    log_step("Git", "Pulling with merge strategy...")
    try:
        result = subprocess.run(
            _build_git_cmd(repo_path, ["pull", "--strategy=recursive", "--strategy-option=theirs"], run_as_user),
            capture_output=True,
            text=True,
            check=True,
        )
        log_success("Git pull with auto-merge successful")
        return True, result.stdout + result.stderr
    except subprocess.CalledProcessError as e:
        log_error("Git pull with auto-merge failed")
        return False, e.stdout + e.stderr
