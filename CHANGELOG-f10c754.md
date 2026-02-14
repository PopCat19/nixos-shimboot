# Changelog — dev-very-experimental → dev

**Date:** 2026-02-14
**Branch:** dev-very-experimental
**Merge commit:** `f10c754`

## Commits

- docs: archive SPEC.md, add lean OVERVIEW.md (`f10c754`)
- docs(development): fix 4 issues from review feedback (`ddf80d5`)
- feat(hyprland): add shaders directory and update shader paths (`052ba95`)
- refactor(screenshot): clean up script comments and simplify code (`98a39d4`)
- docs(development): add section 19 changelog policy (`4ec5fd1`)
- feat(system): reduce zram priority to 80 (`f51987d`)
- refactor(docs): consolidate rules into single DEVELOPMENT.md (`52daeba`)
- fix(environment): use Nix interpolation for NIXOS_PROFILE_DIR (`4653d80`)
- refactor(packages): replace libmtp with tree utility (`3b79352`)
- feat(fcitx5,cnup): consolidate fcitx5 config and add --no-check flag (`c603d61`)
- fix(environment): add dynamic NIXOS_PROFILE_DIR based on selected profile (`057241a`)
- feat(SoT): inject userConfig environment variables into fish shell (`bff4f98`)
- refactor(system): remove _modules and _configuration from directory names (`687dc26`)
- refactor(system): remove system_modules prefix from imports (`050ec0b`)
- fix(env): construct NIXOS_PROFILE_DIR dynamically from NIXOS_CONFIG_DIR (`5d95cfb`)
- refactor(env): use NIXOS_CONFIG_DIR in selected-profile.nix (`ac7a6f5`)
- refactor(user-config): remove unnecessary rec keyword (`3594fad`)
- refactor: use inherit syntax for cleaner code (`4977160`)
- refactor(env): define NIXOS_CONFIG_DIR from user-config.nix (`60fd223`)
- refactor(profile): move NIXOS_PROFILE_DIR to selected-profile.nix (`1577df1`)
- fix(paths): add NIXOS_PROFILE_DIR and fix shader paths (`06faf98`)
- docs(stylix): document builtins.toFile warning from upstream modules (`18e576e`)
- refactor(ci): fix critical issues in CI and build scripts (`d5a8790`)
- fix: correct base_configuration import path (four levels up) (`8f1d47a`)
- fix: correct base_configuration import path in profile (`f262e13`)
- fix: update all references to use profile-based paths (`2b59c32`)
- refactor(shimboot_config): implement profile dispatching system (`fbd392f`)
- refactor(keybinds,user-config): centralize clipboard management (`e7c6e03`)
- refactor(userprefs,packages): remove unused configuration and packages (`f7af51b`)
- refactor(hyprland,shaders,packages): update formatting and configuration (`3ec5b21`)
- refactor(userprefs.conf): remove device-specific configurations (`eac222a`)
- chore(flake): update home-manager and zen-browser inputs (`8dd4049`)
- fix(userprefs.conf): update shader paths and windowrule syntax (`305ebdf`)
- fix(hyprland): update windowrule syntax to new Hyprland format (`0daa750`)
- refactor(shaders): unify comment conventions across shader files (`fae4d71`)
- fix(hypr_config): update shader configuration paths and GLSL syntax (`91dd99c`)
- refactor(cool-stuff.glsl): restructure CRT shader with standardized headers (`125802f`)
- feat(userprefs.conf): update cool-stuff shader toggle to use full path (`3712ad1`)
- chore(flake): update lockfile (`658befe`)
- fix(packages.nix): remove opencode package reference (`99fc46c`)
- feat(proxify.fish): add chromium proxy injection and systemd detachment (`57551d5`)
- feat(proxify): split proxy functions and add completions (`7328933`)
- refactor(fish_functions): split proxy-env into separate function files (`a5cb9ed`)
- Revert non-proxy abbreviation changes (`d01046c`)
- Mirror proxy-env function and nixos-rebuild fix from main config (`ac0b2a9`)
- Mirror proxy-env function and nixos-rebuild fix from main config (`170134b`)
- fix(fish): cnup use treefmt instead of nixfmt-tree (`37d877f`)
- fix(fish): cnup nix-shell package syntax (`58ecba3`)
- feat(fish): add lsa function for git tree view (`d97cc96`)
- unify screenshot script to nix with grimblast (`94f0c1d`)
- feat(fish): restore git status display in greeting (`089cefd`)
- fix(proxy): replace slow shellInit with manual proxy-toggle command (`9534a8c`)
- perf(starship): disable slow segments for faster startup (`c1ed8b0`)
- perf(fish): optimize fish-greeting for instant shell startup (`2a165cd`)
- remove git module from greeting (`6c32369`)
- optimize git caching: only update when HEAD changes (`b4fa6f6`)
- fix: pass self and llm-agents to modules for offline flake check (`41a9436`)
- perf(fish): cache git info in greeting; fix(keybinds): update Mod+A (`e251159`)
- feat: add noctalia restart keybind and port user-level proxy support (`788dcf5`)
- feat: add llm-agents flake input and opencode to main packages (`51cd4f3`)
- fix: use grey color for date line in fish greeting (`a0b3284`)
- fix: use brgrey color for date line in fish greeting (`03befcf`)
- feat: implement show-shortcuts fish function with comment-based parsing (`2cf7dc5`)
- style: remove unused userConfig parameter from proxy module (`c7b610b`)
- feat(proxy.nix): add Android WiFi Direct auto-configuration module (`1c77811`)
- chore: update workflow and build scripts (`c5247c2`)
- docs(.gitignore): add opencode and kilocode directories (`8ee5fa1`)
- chore(flake): update dependencies to latest versions (`27b2709`)
- feat(vscodium.nix): switch to nix-ide extension (`b9ba83c`)
- fix(workflows): update nix fmt flag to fail-on-change (`ad217f4`)
- refactor(nix): apply consistent formatting across all modules (`bc4e18b`)
- refactor(flake, cnup.fish): replace alejandra with nixfmt (`8d73e6f`)
- fix(fetch-manifest): fix vars (`b40847a`)
- docs(SPEC): update hardware support and configuration details (`5422f1b`)
- refactor(headers): update module comment headers (`135c753`)
- update(packages): add android-tools for adb (`fc910d2`)
- refactor(headers): update module comment headers (`14ec5bd`)
- update(power-management): use performance for battery (`337acf8`)
- flake: update noctalia input (`e754663`)
- refactor(hyprland): clean up user preferences (`7ca5632`)
- chore(flake): update project-minimalist-design (`3ee2085`)
- feat(fish): add cnup function for NixOS linting and formatting (`76c392c`)
- feat(base-configuration): add setup-experience module (`06260fe`)
- update readme (`2b61e2a`)
- update(zram): reduce percent 200 -> 100 (`3054492`)
- fix(fcitx5): remove invalid definition (`7e57b61`)
- update(fcitx5): update definitions for wayland (`f15a95d`)
- feat(networking): add pool.ntp.org time server (`078b012`)
- chore(vscodium): replace nix-ide with alejandra (`0605d05`)
- fix(power-management): use valid intel_pstate definitions (`ad3ec5c`)
- fix(power-management): remove CPU frequency governor override (`12b671a`)
- fix(noctalia): add delayed systemd service startup (`90d6e10`)
- refactor(hyprland, noctalia): clean up package dependencies (`a980b51`)
- feat(kitty): add Kitty terminal configuration (`2d1b0ef`)
- refactor(hyprland): integrate Stylix and MD3 animations (`5dd2446`)
- refactor(theming): migrate to Stylix framework with PMD integration (`0e105bc`)
- refactor(fish): integrate helper functions directly into fish environment (`b19377f`)
- refactor(helpers): migrate bash scripts to portable fish scripts (`07ff301`)
- fix(helpers): escape shell variables in helper scripts (`0132dcf`)
- fix(tools): restore executable permissions to shell scripts (`09ee08d`)
- refactor(fish_functions,tools,helpers): standardize logging (`7b90c53`)

## Files changed

 .gitattributes                                     |    1 +
 .github/workflows/flake-check.yml                  |    4 +-
 .github/workflows/shimboot-unified.yml             |   65 +-
 .gitignore                                         |    2 +
 .kilocode/rules/comment-cleanup.md                 |  107 -
 .kilocode/rules/dont-orphan-modules.md             |   58 -
 .kilocode/rules/dry-refactor.md                    |   64 -
 .kilocode/rules/general-conventions.md             |  363 ---
 .kilocode/rules/module.md                          |   95 -
 .kilocode/rules/rule-writing-guidelines.md         |  167 --
 .kilocode/rules/specifications-maintnance.md       |  239 --
 .kilocode/rules/use-context7.md                    |   52 -
 CHANGELOG-f10c754.md                               |  122 +
 DEVELOPMENT.md                                     | 2657 ++++++++++++++++++++
 OVERVIEW.md                                        |   36 +
 quickstart.md => QUICKSTART.md                     |    4 +-
 README.md                                          |   20 +-
 assemble-final.sh                                  |  917 +++----
 SPEC.md => docs/archive/SPEC.md                    |   34 +-
 flake.lock                                         |  172 +-
 flake.nix                                          |  204 +-
 flake_modules/chromeos-sources.nix                 |  100 +-
 flake_modules/development-environment.nix          |    6 +-
 .../patch_initramfs/initramfs-extraction.nix       |   11 +-
 .../patch_initramfs/initramfs-patching.nix         |   11 +-
 .../patch_initramfs/kernel-extraction.nix          |   11 +-
 flake_modules/raw-image.nix                        |  110 +-
 flake_modules/system-configuration.nix             |  166 +-
 scripts/git-intent-watch.sh => git-intent-watch.sh |    0
 llm-notes/commenting-conventions.md                |  157 --
 llm-notes/development-workflow.md                  |  116 -
 overlays/rose-pine-gtk-theme-full.nix              |    8 +-
 .../base_configuration/configuration.nix           |   71 +-
 .../{system_modules => system}/audio.nix           |    3 +-
 .../{system_modules => system}/boot.nix            |    9 +-
 .../{system_modules => system}/display-manager.nix |    3 +-
 .../{system_modules => system}/environment.nix     |   10 +-
 .../{system_modules => system}/filesystems.nix     |    3 +-
 shimboot_config/base_configuration/system/fish.nix |  217 ++
 .../system/fish_functions/cnup.fish                |   39 +
 .../system/fish_functions/completions/proxify.fish |   10 +
 .../system/fish_functions/fish-greeting.fish       |  148 ++
 .../fish_functions/fix-fish-history.fish           |   18 +-
 .../system/fish_functions/list-fish-helpers.fish   |   66 +
 .../system/fish_functions/lsa.fish                 |   40 +
 .../system/fish_functions/nixos-flake-update.fish  |   72 +
 .../fish_functions/nixos-rebuild-basic.fish        |   30 +-
 .../system/fish_functions/proxify.fish             |   45 +
 .../system/fish_functions/proxy_off.fish           |   18 +
 .../system/fish_functions/proxy_on.fish            |   33 +
 .../system/fish_functions/show-shortcuts.fish      |  199 ++
 .../{system_modules => system}/fonts.nix           |   22 +-
 .../{system_modules => system}/hardware.nix        |    3 +-
 .../system/helpers/expand_rootfs.fish              |   95 +
 .../system/helpers/fix-steam-bwrap.fish            |   61 +
 .../base_configuration/system/helpers/helpers.nix  |   31 +
 .../system/helpers/setup_nixos.fish                |  487 ++++
 .../system/helpers/setup_nixos_config.fish         |   85 +
 .../{system_modules => system}/hyprland.nix        |    3 +-
 .../{system_modules => system}/kill-frecon.nix     |    7 +-
 .../{system_modules => system}/localization.nix    |    3 +-
 .../{system_modules => system}/networking.nix      |   11 +-
 .../{system_modules => system}/packages.nix        |   25 +-
 .../power-management.nix                           |    8 +-
 .../base_configuration/system/proxy.nix            |  144 ++
 .../{system_modules => system}/security.nix        |    3 +-
 .../{system_modules => system}/services.nix        |    0
 .../base_configuration/system/setup-experience.nix |   22 +
 .../base_configuration/system/systemd-patch.nix    |   56 +
 .../{system_modules => system}/users.nix           |    3 +-
 .../{system_modules => system}/xdg-portals.nix     |   18 +-
 .../{system_modules => system}/zram.nix            |    7 +-
 .../base_configuration/system_modules/fish.nix     |   60 -
 .../fish_functions/fish-greeting.fish              |   71 -
 .../fish_functions/list-fish-helpers.fish          |   30 -
 .../fish_functions/nixos-flake-update.fish         |   72 -
 .../system_modules/helpers/application-helpers.nix |   50 -
 .../system_modules/helpers/filesystem-helpers.nix  |   81 -
 .../system_modules/helpers/helpers.nix             |   19 -
 .../system_modules/helpers/permissions-helpers.nix |   14 -
 .../system_modules/helpers/setup-helpers.nix       |  563 -----
 .../system_modules/systemd-patch.nix               |   57 -
 shimboot_config/main_configuration/home/fcitx5.nix |   45 -
 .../main_configuration/home/fish-themes.nix        |   15 -
 .../home/fish_themes/Rosé Pine Dawn.theme"         |   41 -
 .../home/fish_themes/Rosé Pine Moon.theme"         |   41 -
 .../home/fish_themes/Rosé Pine.theme"              |   41 -
 shimboot_config/main_configuration/home/fonts.nix  |   20 -
 .../home/hypr_config/hypr_modules/animations.nix   |   43 -
 .../home/hypr_config/hypr_modules/autostart.nix    |   28 -
 .../home/hypr_config/hypr_modules/colors.nix       |    6 -
 .../home/hypr_config/hypr_modules/environment.nix  |   29 -
 .../home/hypr_config/hypr_modules/window-rules.nix |  103 -
 .../home/hypr_config/hyprpaper.conf                |    2 -
 .../hypr_config/shaders/blue-light-filter.glsl     |   82 -
 .../home/hypr_config/shaders/cool-stuff.glsl       |  395 ---
 .../home/hypr_config/userprefs.conf                |   87 -
 .../home/noctalia_config/module.nix                |   33 -
 .../home/noctalia_config/noctalia.nix              |   16 -
 .../main_configuration/home/screenshot.fish        |  139 -
 166 files changed, 7166 insertions(+), 5810 deletions(-)

## Summary

Major changes in this merge:
- **Documentation**: Consolidated rules into DEVELOPMENT.md, archived SPEC.md, added OVERVIEW.md
- **Profile system**: Implemented profile dispatching for multi-configuration support
- **Performance**: Optimized fish shell startup, git caching, proxy handling
- **Hyprland**: Added shaders, updated keybinds, integrated Stylix theming
- **CI/CD**: Fixed workflow issues, updated formatters
