#!/usr/bin/env fish

# LSA Function
#
# Purpose: Display git-tracked files as a tree structure
# Dependencies: git, tree
# Related: list-fish-helpers.fish, fish.nix
#
# This function:
# - Checks if current directory is a git repository
# - Lists all git-tracked files using git ls-files
# - Pipes output to tree command for visual representation
# - Provides helpful error messages if tools are missing

function lsa
    if not command -q tree
        set_color red; echo "[ERROR] tree command not found"; set_color normal
        set_color cyan; echo "[INFO] Install tree: nix-shell -p tree"; set_color normal
        return 1
    end

    if not test -d .git
        set_color red; echo "[ERROR] Not a git repository"; set_color normal
        set_color cyan; echo "[INFO] Run this function from within a git repository"; set_color normal
        return 1
    end

    git ls-files | tree --fromfile
end
