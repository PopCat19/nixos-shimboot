# nixos-status.fish
#
# Purpose: Display NixOS system status and health information
#
# Usage:
#   nixos-status          # Show full system status
#   nixos-status --gen    # Show generation history only
#   nixos-status --store  # Show nix store statistics only
#   nixos-status --clean  # Clean old generations and optimize store
#
# Shows:
#   - Current system version and generation
#   - Kernel version and boot entries
#   - Available generations with dates
#   - Nix store size and optimization status
#   - Home Manager generations (if available)

function nixos-status
    set -l show_generations true
    set -l show_store true
    set -l clean_mode false

    # Parse arguments
    for arg in $argv
        switch $arg
            case "--gen"
                set show_store false
            case "--store"
                set show_generations false
            case "--clean"
                set clean_mode true
            case "--help" "-h"
                echo "Usage: nixos-status [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --gen     Show generation history only"
                echo "  --store   Show nix store statistics only"
                echo "  --clean   Clean old generations and optimize store"
                echo "  --help    Show this help message"
                return 0
        end
    end

    # Clean mode: run garbage collection and optimization
    if test "$clean_mode" = true
        set_color blue; echo "╔══════════════════════════════════════════════════════════════╗"; set_color normal
        set_color blue; echo "│                    NixOS Store Cleanup                        │"; set_color normal
        set_color blue; echo "╚══════════════════════════════════════════════════════════════╝"; set_color normal
        echo ""

        # Delete old generations
        set_color cyan; echo "[STEP] Removing old generations..."; set_color normal
        sudo nix-collect-garbage -d

        # Optimize store
        set_color cyan; echo "[STEP] Optimizing nix store..."; set_color normal
        sudo nix-store --optimize

        # Repair references (optional, can fix broken symlinks)
        set_color cyan; echo "[STEP] Verifying store integrity..."; set_color normal
        sudo nix-store --verify --check-contents --repair

        set_color green; echo "[SUCCESS] Cleanup complete!"; set_color normal
        return 0
    end

    # Header
    set_color blue; echo "╔══════════════════════════════════════════════════════════════╗"; set_color normal
    set_color blue; echo "│                    NixOS System Status                        │"; set_color normal
    set_color blue; echo "╚══════════════════════════════════════════════════════════════╝"; set_color normal
    echo ""

    # System information
    set_color green; echo "┌── System Information ─────────────────────────────────────────"; set_color normal
    set_color white; echo "│ OS: "(set_color cyan)(nixos-version)(set_color normal); set_color normal
    set_color white; echo "│ Kernel: "(set_color cyan)(uname -r)(set_color normal); set_color normal
    set_color white; echo "│ Hostname: "(set_color cyan)(hostname)(set_color normal); set_color normal
    set_color white; echo "│ Uptime: "(set_color cyan)(uptime | string replace 'up ' '')(set_color normal); set_color normal
    set_color green; echo "└──────────────────────────────────────────────────────────────"; set_color normal
    echo ""

    # Current generation
    if test "$show_generations" = true
        set_color green; echo "┌── Current Generation ────────────────────────────────────────"; set_color normal

        set -l current_gen (readlink /nix/var/nix/profiles/system)
        set -l gen_number (basename $current_gen | string replace 'system-' '')

        # Get generation creation time
        set -l gen_info (nixos-rebuild list-generations 2>/dev/null | grep -E "^$gen_number\s")
        if test -n "$gen_info"
            set -l gen_time (echo $gen_info | awk '{print $2 " " $3}')
            set_color white; echo "│ Generation: "(set_color cyan)"$gen_number"(set_color normal)" (built $gen_time)"; set_color normal
        else
            set_color white; echo "│ Generation: "(set_color cyan)"$gen_number"(set_color normal); set_color normal
        end

        # Show boot entries count
        set -l boot_entries (ls /boot/loader/entries/ 2>/dev/null | wc -l)
        if test $boot_entries -gt 0
            set_color white; echo "│ Boot entries: "(set_color cyan)"$boot_entries"(set_color normal); set_color normal
        end

        set_color green; echo "└──────────────────────────────────────────────────────────────"; set_color normal
        echo ""

        # Generation history
        set_color green; echo "┌── Recent Generations ────────────────────────────────────────"; set_color normal
        nixos-rebuild list-generations 2>/dev/null | head -10 | while read -l gen_line
            set -l parts (string split ' ' $gen_line)
            set -l gen_num $parts[1]
            set -l gen_date $parts[2]
            set -l gen_time $parts[3]
            set -l gen_kernel $parts[4]

            # Highlight current generation
            if test "/nix/var/nix/profiles/system-$gen_num" = "$current_gen"
                set_color cyan; echo "│ ★ $gen_num  $gen_date $gen_time  (kernel: $gen_kernel)"; set_color normal
            else
                set_color white; echo "│   $gen_num  $gen_date $gen_time  (kernel: $gen_kernel)"; set_color normal
            end
        end
        set_color green; echo "└──────────────────────────────────────────────────────────────"; set_color normal
        echo ""
    end

    # Nix store statistics
    if test "$show_store" = true
        set_color green; echo "┌── Nix Store ─────────────────────────────────────────────────"; set_color normal

        # Store size
        set -l store_size (du -sh /nix/store 2>/dev/null | cut -f1)
        set_color white; echo "│ Store size: "(set_color cyan)"$store_size"(set_color normal); set_color normal

        # Store paths count
        set -l path_count (ls /nix/store 2>/dev/null | wc -l)
        set_color white; echo "│ Total paths: "(set_color cyan)"$path_count"(set_color normal); set_color normal

        # Garbage collection info
        set -l gc_bytes (nix-store --gc --print-dead 2>/dev/null | tail -1 | string replace 'bytes ' '')
        if test -n "$gc_bytes"
            # Convert to human readable
            set -l gc_mb (math "$gc_bytes / 1048576")
            set_color white; echo "│ Reclaimable: "(set_color yellow)"~$gc_mb MB"(set_color normal)" (run 'nixos-status --clean')"; set_color normal
        end

        set_color green; echo "└──────────────────────────────────────────────────────────────"; set_color normal
        echo ""
    end

    # Home Manager status (if available)
    if test -d "$HOME/.local/share/home-manager"
        set_color green; echo "┌── Home Manager ──────────────────────────────────────────────"; set_color normal

        set -l hm_generations (ls -1 $HOME/.local/share/home-manager/generations 2>/dev/null | wc -l)
        set_color white; echo "│ Generations: "(set_color cyan)"$hm_generations"(set_color normal); set_color normal

        # Show current home-manager generation
        set -l hm_current (readlink $HOME/.local/state/home-manager/gcroots/current-home 2>/dev/null)
        if test -n "$hm_current"
            set -l hm_gen_name (basename $hm_current)
            set_color white; echo "│ Current: "(set_color cyan)"$hm_gen_name"(set_color normal); set_color normal
        end

        set_color green; echo "└──────────────────────────────────────────────────────────────"; set_color normal
        echo ""
    end

    # Quick commands reminder
    set_color yellow; echo "💡 Quick Commands:"; set_color normal
    set_color white; echo "   nixos-rebuild switch --flake .  # Rebuild system"; set_color normal
    set_color white; echo "   nixos-status --clean            # Clean old generations"; set_color normal
    set_color white; echo "   nixos-rebuild list-generations  # Full generation list"; set_color normal
end