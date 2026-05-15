# nixos-rebuild-basic.fish
#
# Purpose: Unified NixOS rebuild with commit/push support
#
# This module:
# - Detects nh availability and falls back to nixos-rebuild
# - Performs git commit/push workflow around rebuild
# - Supports system generation rollback and dry-run builds
# - Always disables sandbox for shimboot compatibility

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
    set -l rollback_on_fail false
    set -l do_system_rollback false
    set -l force_no_sandbox false
    set -l did_commit false
    set -l extra_args

    set -l i 1
    while test $i -le (count $argv)
        switch $argv[$i]
            case "--dry-run" "dry-run"
                set action "build"
            case "--test" "test"
                set action "test"
            case "--auto" "auto"
                set auto_mode true
                set rollback_on_fail true  # Default rollback in auto mode
            case "--push" "push"
                set push_on_success true
            case "--no-push" "no-push"
                set no_push true
            case "--rollback" "rollback"
                set do_system_rollback true
            case "--no-rollback" "no-rollback"
                set rollback_on_fail false
            case "--no-sandbox" "no-sandbox"
                set force_no_sandbox true
            case "--*"
                # Capture all other double-dash flags (like --offline)
                set -a extra_args $argv[$i]
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

    # Detect build tool (nh preferred, nixos-rebuild fallback)
    set -l use_nh false
    if command -q nh
        set use_nh true
    end

    # Prepare proxy environment variables for sudo
    set -l proxy_env
    if set -q all_proxy
        set -a proxy_env http_proxy=$http_proxy
        set -a proxy_env https_proxy=$https_proxy
        set -a proxy_env all_proxy=$all_proxy
        set -a proxy_env no_proxy=$no_proxy
        set -a proxy_env HTTP_PROXY=$http_proxy
        set -a proxy_env HTTPS_PROXY=$https_proxy
        set -a proxy_env ALL_PROXY=$all_proxy
        set -a proxy_env NO_PROXY=$no_proxy
    end

    # System rollback: switch to previous generation, skip rebuild
    if test "$do_system_rollback" = true
        if test "$auto_mode" = true
            echo "[STEP] Rolling back to previous NixOS generation..."
            if test "$use_nh" = true
                sudo $proxy_env nh os rollback --bypass-root-check
            else
                sudo $proxy_env nixos-rebuild switch --rollback
            end
            if test $status -eq 0
                echo "[SUCCESS] Rolled back to previous generation"
                cd $original_dir
                return 0
            else
                echo "[ERROR] Rollback failed" >&2
                cd $original_dir
                return 1
            end
        else
            set_color blue; echo "[STEP] Rolling back to previous NixOS generation..."; set_color normal
            if test "$use_nh" = true
                sudo $proxy_env nh os rollback --bypass-root-check
            else
                sudo $proxy_env nixos-rebuild switch --rollback
            end
            if test $status -eq 0
                set_color green; echo "[SUCCESS] Rolled back to previous generation"; set_color normal
                cd $original_dir
                return 0
            else
                set_color red; echo "[ERROR] Rollback failed"; set_color normal
                cd $original_dir
                return 1
            end
        end
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

    # Rebuild phase
    set -l flake_target (hostname)

    # Build arguments
    set -l rebuild_cmd
    set -l rebuild_args $action
    if test "$use_nh" = true
        set rebuild_cmd sudo $proxy_env nh os
        set -a rebuild_args $NIXOS_CONFIG_DIR --hostname $flake_target --bypass-root-check

        # Pass extra flags (like --offline) to nix via --
        if test -n "$extra_args"
            set -a rebuild_args -- $extra_args
        end
    else
        set rebuild_cmd sudo $proxy_env nixos-rebuild
        set -a rebuild_args --flake $NIXOS_CONFIG_DIR#$flake_target

        if test -n "$extra_args"
            set -a rebuild_args $extra_args
        end
    end

    # Sandbox is always disabled for shimboot to support old kernels in fleet
    if test "$auto_mode" = true
        echo "[INFO] Sandbox disabled (shimboot policy)"
    else
        set_color yellow; echo "[INFO] Sandbox disabled (shimboot policy)"; set_color normal
    end

    if test "$use_nh" = true
        set -a rebuild_args -- --option sandbox false
    else
        set -a rebuild_args --option sandbox false
    end

    if test "$auto_mode" = true
        echo "[STEP] Running $rebuild_cmd $rebuild_args..."
        if $rebuild_cmd $rebuild_args
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
        set_color blue; echo "[STEP] Running rebuild..."; set_color normal
        set_color cyan; echo "Command: $rebuild_cmd $rebuild_args"; set_color normal

        if not $rebuild_cmd $rebuild_args
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