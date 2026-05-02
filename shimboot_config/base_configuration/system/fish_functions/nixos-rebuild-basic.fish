# nixos-rebuild-basic.fish
#
# Purpose: Unified NixOS rebuild with commit/push support
#
# Usage:
#   nrb                           # Just rebuild
#   nrb "commit message"          # Commit + rebuild + push
#   nrb --dry-run                 # Build without switching
#   nrb --dry-run "msg"           # Commit + dry-run
#   nrb --auto "msg"              # Non-interactive (LLM mode)
#   nrb --auto --push "msg"       # Non-interactive with push
#   nrb --test "msg"              # Test build (no switch)
#
# Options:
#   --dry-run       Build without switching
#   --test          Test configuration without switching
#   --auto          Non-interactive mode (no prompts, clear exit codes)
#   --push          Push after success (implies commit message required)
#   --no-push       Skip push even with commit message
#   --rollback      Rollback commit on failure (default in auto mode)
#   --no-rollback   Keep changes on failure
#
# Exit codes (auto mode):
#   0 - Success
#   1 - Build failed
#   2 - Commit failed
#   3 - Push failed

function nixos-rebuild-basic
    # Validate NIXOS_CONFIG_DIR
    if not set -q NIXOS_CONFIG_DIR; or not test -d "$NIXOS_CONFIG_DIR"
        set_color red; echo "[ERROR] NIXOS_CONFIG_DIR is not set or invalid."; set_color normal
        return 1
    end

    set -l original_dir (pwd)
    cd "$NIXOS_CONFIG_DIR"

    # Parse arguments
    set -l commit_message ""
    set -l action "switch"
    set -l auto_mode false
    set -l push_on_success false
    set -l no_push false
    set -l rollback_on_fail false  # Default: no rollback in interactive mode
    set -l did_commit false

    set -l i 1
    while test $i -le (count $argv)
        switch $argv[$i]
            case "--dry-run"
                set action "build"
            case "--test"
                set action "test"
            case "--auto"
                set auto_mode true
                set rollback_on_fail true  # Default rollback in auto mode
            case "--push"
                set push_on_success true
            case "--no-push"
                set no_push true
            case "--rollback"
                set rollback_on_fail true
            case "--no-rollback"
                set rollback_on_fail false
            case "*"
                if test -z "$commit_message"
                    set commit_message $argv[$i]
                else
                    set commit_message "$commit_message $argv[$i]"
                end
        end
        set i (math $i + 1)
    end

    # In auto mode with --push, require commit message
    if test "$auto_mode" = true; and test "$push_on_success" = true; and test -z "$commit_message"
        echo "[ERROR] Commit message required with --push flag" >&2
        cd $original_dir
        return 2
    end

    set -l pre_commit_hash (git rev-parse HEAD)

    # Commit phase
    if test -n "$commit_message"
        git add .

        if git diff --cached --quiet
            if test "$auto_mode" = true
                echo "[INFO] Nothing to commit"
            else
                set_color green; echo "[INFO] Nothing to commit; proceeding with rebuild"; set_color normal
            end
        else
            if git commit -m "$commit_message"
                set did_commit true
                if test "$auto_mode" = true
                    echo "[INFO] Committed: $commit_message"
                else
                    set_color green; echo "[INFO] Committed: $commit_message"; set_color normal
                end
            else
                if test "$auto_mode" = true
                    echo "[ERROR] Commit failed" >&2
                    cd $original_dir
                    return 2
                else
                    set_color yellow; echo "[WARN] Commit failed; proceeding with rebuild"; set_color normal
                end
            end
        end
    end

    # Build nixos-rebuild arguments
    set -l rebuild_args $action --flake .

    # Kernel < 5.6 lacks sandbox support (ChromeOS shim kernels)
    set -l kver (uname -r)
    if string match -qr '^([0-4]\.|5\.[0-5][^0-9])' "$kver"
        if test "$auto_mode" = true
            echo "[WARN] Kernel $kver (< 5.6) detected. Disabling sandbox."
        else
            set_color yellow; echo "[WARN] Kernel $kver (< 5.6) detected. Disabling sandbox."; set_color normal
        end
        set -a rebuild_args --option sandbox false
    end

    # Rebuild phase
    # Get display name for flake target
    set -l flake_dir (basename $NIXOS_CONFIG_DIR)
    set -l flake_target (hostname)
    set -l flake_display "$flake_dir#$flake_target"

    if test "$auto_mode" = true
        echo "[STEP] Running nixos-rebuild $action for $flake_display..."
        set -l result
        if sudo nixos-rebuild $rebuild_args
            echo "[SUCCESS] Build succeeded"
        else
            echo "[ERROR] Build failed" >&2
            if test "$rollback_on_fail" = true; and test "$did_commit" = true
                echo "[STEP] Rolling back to: $pre_commit_hash"
                git reset --hard $pre_commit_hash
            end
            cd $original_dir
            return 1
        end
    else
        set_color blue; echo "[STEP] Running NixOS rebuild..."; set_color normal
        set_color cyan; echo "Command: sudo nixos-rebuild $action --flake $flake_display"; set_color normal

        if not sudo nixos-rebuild $rebuild_args
            set_color red; echo "[ERROR] Build failed"; set_color normal

            if test "$did_commit" = true; and test "$rollback_on_fail" = true
                git reset --hard $pre_commit_hash
                set_color blue; echo "[STEP] Rolled back to: $pre_commit_hash"; set_color normal
            else if test "$did_commit" = true
                set_color yellow; echo "[WARN] Changes kept. Rollback with: git reset --hard $pre_commit_hash"; set_color normal
            end

            cd $original_dir
            return 1
        end

        set_color green; echo "[SUCCESS] Build succeeded"; set_color normal
    end

    # Push phase
    if test "$no_push" = true
        cd $original_dir
        return 0
    end

    # Determine if we should push
    set -l should_push false
    if test -n "$commit_message"
        set should_push true  # Default: push when commit message provided
    end
    if test "$push_on_success" = true
        set should_push true
    end
    if test "$did_commit" = false
        set should_push false
    end

    if test "$should_push" = true
        set -l branch (git branch --show-current)

        if test "$auto_mode" = true
            echo "[STEP] Pushing to remote..."
            if git push 2>/dev/null
                echo "[SUCCESS] Pushed to origin/$branch"
                cd $original_dir
                return 0
            end

            # Auto: try rebase then force push
            echo "[STEP] Normal push failed, trying rebase..."
            git fetch origin

            if git pull --rebase origin $branch 2>/dev/null
                if git push 2>/dev/null
                    echo "[SUCCESS] Rebased and pushed to origin/$branch"
                    cd $original_dir
                    return 0
                else
                    echo "[ERROR] Push failed after rebase" >&2
                    cd $original_dir
                    return 3
                end
            else
                echo "[ERROR] Rebase failed, manual intervention required" >&2
                cd $original_dir
                return 3
            end
        else
            # Interactive push with conflict handling
            if git push 2>/dev/null
                set_color green; echo "[SUCCESS] Changes pushed to remote"; set_color normal
            else
                set_color yellow; echo "[WARN] Normal push failed - likely due to diverged history"; set_color normal
                set_color cyan; echo "[INFO] This can happen after rollbacks or when remote is ahead"; set_color normal

                set_color blue; echo "[STEP] Fetching latest remote changes..."; set_color normal
                git fetch origin

                read -l -P "Try rebase to integrate remote changes? [y/N]: " rebase_choice

                set -l pushed false
                if test "$rebase_choice" = "y"; or test "$rebase_choice" = "Y"
                    set_color blue; echo "[STEP] Rebasing local commits onto remote $branch..."; set_color normal
                    if git pull --rebase origin $branch
                        set_color green; echo "[SUCCESS] Rebase successful, trying push..."; set_color normal
                        if git push 2>/dev/null
                            set_color green; echo "[SUCCESS] Changes pushed to remote"; set_color normal
                            set pushed true
                        end
                    else
                        set_color red; echo "[ERROR] Rebase failed (likely merge conflicts)"; set_color normal
                    end
                end

                if test "$pushed" = false
                    set_color red; echo "[ERROR] Push failed. Force push required."; set_color normal
                    read -l -P "Proceed with force push? [y/N]: " force_choice

                    if test "$force_choice" = "y"; or test "$force_choice" = "Y"
                        git push --force-with-lease
                        set_color green; echo "[SUCCESS] Changes force-pushed to remote"; set_color normal
                    else
                        set_color yellow; echo "[WARN] Changes not pushed. Push manually with: git push --force-with-lease"; set_color normal
                    end
                end
            end
        end
    end

    cd $original_dir
    return 0
end