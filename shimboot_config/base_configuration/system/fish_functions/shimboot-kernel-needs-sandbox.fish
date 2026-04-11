#!/usr/bin/env fish

# shimboot-kernel-needs-sandbox.fish
#
# Purpose: Detect whether the running kernel requires Nix sandbox disabled
#
# This module:
# - Checks kernel version against 5.6 threshold
# - Returns 0 if sandbox must be disabled, 1 otherwise

function shimboot-kernel-needs-sandbox
    string match -qr '^([0-4]\.|5\.[0-5][^0-9])' (uname -r)
end