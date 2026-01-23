#!/usr/bin/env fish

# LSA Function
#
# Purpose: Display git-tracked files as a tree structure
# Dependencies: git, tree
# Related: list-fish-helpers.fish, fish.nix
#
# This function:
# - Checks if current directory is a git repository or subdirectory
# - Lists all git-tracked files using git ls-files
# - Pipes output to tree command for visual representation
# - Provides helpful error messages if tools are missing

function lsa
    if not command -q tree
        set_color red; echo "[ERROR] tree command not found"; set_color normal
        set_color cyan; echo "[INFO] Install tree: nix-shell -p tree"; set_color normal
        return 1
    end

    # Check if in home directory (skip git check)
    if string match -qr '^$HOME($|/)' (pwd)
        set_color yellow; echo "[INFO] In home directory, skipping git repository check"; set_color normal
        return 0
    end

    # Find git root (works in subdirectories)
    set -l git_root (git rev-parse --show-toplevel 2>/dev/null)
    if test -z "$git_root"
        set_color red; echo "[ERROR] Not in a git repository"; set_color normal
        set_color cyan; echo "[INFO] Run this function from within a git repository (except home)"; set_color normal
        return 1
    end

    # Run from git root to get full tree
    pushd "$git_root"
    git ls-files | tree --fromfile
    popd
end
