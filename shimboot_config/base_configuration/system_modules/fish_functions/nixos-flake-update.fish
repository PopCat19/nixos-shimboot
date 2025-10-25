# NixOS Flake Update Function
#
# Purpose: Update NixOS flake inputs with backup and change detection
# Dependencies: nix, jq, diff (optional)
# Related: fish-functions.nix, fish.nix
#
# This function:
# - Creates backup of flake.lock before update
# - Performs nix flake update
# - Shows diff of changes made
# - Provides next steps for applying updates

function nixos-flake-update
    set -l original_dir (pwd)
    cd $NIXOS_CONFIG_DIR

    echo "🔄 Updating NixOS flake inputs..."
    echo ""

    # Check kernel version for sandbox compatibility
    set -l kver (uname -r)
    set -l disable_sandbox 0
    set -l nix_update_args ""

    if string match -qr '^([0-9]+)\.([0-9]+)' $kver
        set -l major (string split . $kver)[1]
        set -l minor (string split . $kver)[2]
        if test $major -lt 5 -o \( $major -eq 5 -a $minor -lt 6 \)
            set disable_sandbox 1
        end
    else
        echo "⚠️  Warning: Could not parse kernel version $kver. Assuming sandbox is supported."
    end

    if test $disable_sandbox -eq 1
        echo "⚠️  Kernel $kver detected (< 5.6). Disabling nix sandbox for flake update."
        set nix_update_args "--option sandbox false"
    else
        echo "🔐 Kernel $kver detected (>= 5.6). Using default sandboxed build."
    end

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
    if nix flake update $nix_update_args
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
                echo "   • Test your configuration: nrb dry-run"
                echo "   • Apply changes: nrb switch"
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