function nixos-flake-update
    set -l original_dir (pwd)
    cd $NIXOS_CONFIG_DIR

    echo "🔄 Updating NixOS flake inputs..."
    echo ""

    # Create backup of current flake.lock
    if test -f flake.lock
        cp flake.lock flake.lock.bak
        echo "💾 Backup created: flake.lock.bak"
    else
        echo "⚠️  No existing flake.lock found"
    end

    # Store current flake.lock content for comparison
    set -l old_lock_content ""
    if test -f flake.lock
        set old_lock_content (cat flake.lock)
    end

    # Perform flake update
    echo "📦 Running nix flake update..."
    if nix flake update
        echo "✅ Flake update completed successfully"
        echo ""

        # Check if anything actually changed
        if test -f flake.lock
            set -l new_lock_content (cat flake.lock)

            if test "$old_lock_content" = "$new_lock_content"
                echo "ℹ️  No changes detected - all inputs were already up to date"
            else
                echo "📊 Changes detected in flake.lock:"
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

                # Show diff if available
                if command -v diff >/dev/null
                    diff --unified=3 --color=always flake.lock.bak flake.lock 2>/dev/null; or begin
                        echo "📝 Detailed diff:"
                        diff --unified=3 flake.lock.bak flake.lock 2>/dev/null; or echo "   (diff command failed, but changes were detected)"
                    end
                else
                    echo "📝 Changes detected but diff command not available"
                end

                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                echo ""

                # Show summary of what inputs were updated
                echo "🔍 Analyzing updated inputs..."
                if command -v jq >/dev/null
                    set -l updated_inputs (jq -r '.nodes | to_entries[] | select(.value.locked) | .key' flake.lock 2>/dev/null | head -10)
                    if test -n "$updated_inputs"
                        echo "📋 Updated inputs:"
                        for input in $updated_inputs
                            echo "   • $input"
                        end
                    end
                else
                    echo "   (jq not available for detailed analysis)"
                end

                echo ""
                echo "💡 Next steps:"
                echo "   • Test your configuration: nixos-rebuild dry-run --flake ."
                echo "   • Apply changes: nixos-commit-rebuild-push 'flake update'"
                echo "   • Restore backup if needed: mv flake.lock.bak flake.lock"
            end
        else
            echo "⚠️  flake.lock not found after update"
        end
    else
        echo "❌ Flake update failed"

        if test -f flake.lock.bak
            echo "🔄 Restoring backup..."
            mv flake.lock.bak flake.lock
            echo "✅ Backup restored"
        end

        cd $original_dir
        return 1
    end

    cd $original_dir
end