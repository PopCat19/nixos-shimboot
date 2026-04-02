# Branch-Based Architecture: Base vs Personal Configs

## Problem

The repo mixes shimboot build infrastructure with personal config (popcat19's setup).
Everything is cloned into `/home/USER/nixos-config` during assembly, making it impossible
to have clean separation between "base system" and "personal customization."

## Solution

Branch-based separation with separate files per branch (simpler approach,
no cross-branch imports). Each branch has its own complete set of files.

---

## Branch Structure

| Branch | GitHub Default | Purpose | Inherits From |
|--------|---------------|---------|---------------|
| `main` | Yes | Build infra + minimal working base (LightDM + Hyprland + Kitty) | - |
| `dev` | No | Development for base changes | `main` |
| `default` | No | Stable daily driver template (sensible defaults for anyone) | `main` |
| `dev-default` | No | Development for default branch changes | `default` |
| `popcat19-dev` | No | Personal dev config | `default` |
| `popcat19` | No | Personal stable (merged from popcat19-dev) | `popcat19-dev` |

### Flow

```
main (stable base)
├── dev (base development)
│   └── changes merge to main
├── default (stable daily driver)
│   ├── dev-default (daily driver development)
│   │   └── changes merge to default
│   └── popcat19-dev (personal dev)
│       └── popcat19 (personal stable)
```

---

## Step 1: Create `default` branch from current `dev`

```bash
git checkout dev
git checkout -b default
```

---

## Step 2: Modify `shimboot_config/user-config.nix`

Add timezone detection with build-host mismatch warning:

```nix
{
  lib,
  ...
}:
let
  buildHostTz = builtins.getEnv "TIMEZONE";
  detectedTz = if buildHostTz != "" then buildHostTz else "UTC";
in
{
  # Timezone: detect from build env, warn if mismatched
  timezone = detectedTz;

  # Warnings injected via assertions if TIMEZONE env var differs from detected
  # (Implement via assertion module or during flake evaluation)
}
```

Other changes for `default` branch `user-config.nix`:
- `username = "nixos-user"`
- `hostname = "nixos-shimboot"`
- `theme.hue = null` (use defaults)
- `theme.variant = "dark"`
- `timezone = detectedTz` (with warning)

---

## Step 3: Modify `flake.nix` inputs

**`default` branch flake.nix inputs:**
```nix
inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  nixpkgs-systemd.url = "github:NixOS/nixpkgs/0182a361324364ae3f436a63005877674cf45efb";
  home-manager = { url = "github:nix-community/home-manager"; inputs.nixpkgs.follows = "nixpkgs"; };
  stylix = { url = "github:nix-community/stylix"; inputs.nixpkgs.follows = "nixpkgs"; };
  zen-browser = { url = "github:0xc000022070/zen-browser-flake"; inputs.nixpkgs.follows = "nixpkgs"; };
  rose-pine-hyprcursor = { url = "github:ndom91/rose-pine-hyprcursor"; inputs.nixpkgs.follows = "nixpkgs"; };
  noctalia = { url = "github:noctalia-dev/noctalia-shell"; inputs.nixpkgs.follows = "nixpkgs"; };
  pmd = { url = "github:popcat19/project-minimalist-design/dev"; inputs.nixpkgs.follows = "nixpkgs"; };
};
```

Removed inputs: `llm-agents`, `nixvim`

Update `outputs` destructuring and module calls to match.

---

## Step 4: Modify `shimboot_config/main_configuration/home/home.nix`

Remove excluded imports:

```nix
{
  imports = [
    ./hypr_config/hyprland.nix
    ./noctalia_config/noctalia.nix
    ./hypr_config/hypr-packages.nix
    ./kitty.nix

    ./environment.nix
    ./packages.nix
    ./services.nix
    ./zen-browser.nix

    ./fcitx5.nix
    ./dolphin.nix
    ./fuzzel.nix
    ./bookmarks.nix
    ./kde.nix
    ./micro.nix
    ./privacy.nix
    ./stylix.nix
    ./wallpaper.nix
    ./programs.nix
  ];

  home.stateVersion = "24.11";
}
```

Removed: vesktop.nix, vscodium.nix, tmux.nix, libreoffice.nix, screenshot.nix

---

## Step 5: Modify `shimboot_config/main_configuration/home/programs.nix`

Empty it (all imported editors are excluded):

```nix
_: {
  imports = [ ];
}
```

---

## Step 6: Modify `shimboot_config/main_configuration/home/packages.nix`

Remove communication category:

```nix
{
  imports = [
    ./packages/media.nix
    ./packages/utilities.nix
  ];
}
```

---

## Step 7: Modify `shimboot_config/main_configuration/home/packages/utilities.nix`

```nix
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    eza
    wl-clipboard
    cliphist
    pavucontrol
    playerctl
    localsend
    keepassxc
    zenity
    ripgrep
    android-tools
    nixd
    nil
    nixfmt-tree
    statix
    deadnix
  ];
}
```

Removed: vscodium, biome, pylint, ruff

---

## Step 8: Modify `shimboot_config/main_configuration/home/packages/media.nix`

```nix
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    mpv
  ];
}
```

Removed: pureref, scrcpy

---

## Step 9: Modify `shimboot_config/main_configuration/home/hypr_config/hypr_modules/autostart.nix`

Remove personal items:
- Remove `"openrgb -p orang-full"` line
- Remove `"hyprctl plugin load .../libscrolling.so"` line

---

## Step 10: Modify `shimboot_config/main_configuration/home/hypr_config/userprefs.conf`

Create minimal version:
```conf
# Minimal user preferences
# Sane defaults for most users
# Customize in ~/.config/hypr/userprefs.conf

general {
    sensitivity = 1.0
}

device {
    name = "touchpad"
    scroll_factor = 1.0
}
```

Remove personal keybinds, sensitivity overrides, hyprshade exec lines.

---

## Step 11: Remove files not in default branch

```bash
rm -rf shimboot_config/main_configuration/home/hypr_config/archived_hyprpanel/
rm -rf shimboot_config/main_configuration/home/hypr_config/archived_hyprpaper/
rm -f shimboot_config/main_configuration/home/hypr_config/shaders/bloom.glsl
rm -f shimboot_config/main_configuration/home/hypr_config/shaders/cool-stuff.glsl
```

Keep only `blue-light-filter.glsl` in shaders/.

---

## Step 12: Modify `shimboot_config/main_configuration/home/bookmarks.nix`

Remove `syncthing-shared` entry from Dolphin bookmarks (lines 55-57).

---

## Step 13: Modify `shimboot_config/main_configuration/system/packages.nix`

```nix
{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    gh
    usbutils
    tree
    xdg-utils
    nodejs
    python3
    rustup
    eza
  ];
}
```

Removed: ranger, dolphin+kio-extras (handled by home-manager), jql, llm-agents refs

---

## Step 14: Modify `flake_modules/system-configuration.nix`

Update `mainModules` and `baseModules` references.
Add error handling for `--rootfs full` on main branch.

---

## Step 15: Commit `default` branch

```bash
git add -A
git commit -m "feat(default): scaffold default daily driver branch from dev"
git push origin default
```

---

## Step 16: Create `dev-default` branch from `default`

```bash
git checkout default
git checkout -b dev-default
git push origin dev-default
```

`dev-default` is identical to `default` at creation. It serves as the development
branch for daily driver changes. Work flows: `dev-default` → merge to `default` when stable.

---

## Step 17: Create `popcat19-dev` branch from `default`

```bash
git checkout default
git checkout -b popcat19-dev
```

---

## Step 18: Restore personal configs on `popcat19-dev`

For each changed file in steps 4-15, restore the original version from `dev` branch.
Use `git checkout dev -- <file>` for files that should keep their `dev` content,
or edit to add back personal items.

Key files to restore:
- `shimboot_config/user-config.nix` → username=popcat19, timezone=America/New_York, hue=30
- `flake.nix` → add llm-agents, nixvim inputs back
- `home.nix` → add back all excluded imports
- `programs.nix` → restore full imports (nvim, helix, zathura, broot, lazygit)
- `packages.nix` → restore communication.nix
- `utilities.nix` → restore vscodium, biome, pylint, ruff
- `media.nix` → restore pureref, scrcpy
- `autostart.nix` → restore openrgb and hyprctl plugin load
- `userprefs.conf` → restore personal version
- `bookmarks.nix` → restore syncthing-shared
- `system/packages.nix` → restore full list with llm-agents
- Restore archived_hyprpanel/, archived_hyprpaper/, cool-stuff.glsl, bloom.glsl
- Restore screenshot.nix, vesktop.nix, vscodium.nix, tmux.nix, libreoffice.nix, etc.

---

## Step 18: Update `main` branch

```bash
git checkout main
```

Modify `flake_modules/system-configuration.nix`:
- Remove `mainModules` (or make it error)
- Keep `baseModules` only (minimal with LightDM + Hyprland + Kitty)
- Add error for `--rootfs full`:

In `flake_modules/raw-image.nix`, remove or error on `raw-rootfs` package,
keep only `raw-rootfs-minimal`.

---

## Step 19: Update `tools/build/assemble-final.sh`

Add `--config-branch` argument support:

```bash
# In argument parsing section, add:
--config-branch)
    CONFIG_BRANCH="$2"
    shift 2
    ;;
```

Modify Step 15 (line 1014) to use config branch if specified:

```bash
# Default: clone same branch
# With --config-branch: clone specified branch
CLONE_BRANCH="${CONFIG_BRANCH:-$GIT_BRANCH}"
safe_exec sudo git clone --branch "$CLONE_BRANCH" --no-local "$(pwd)" "$NIXOS_CONFIG_DEST"
```

Add error for `--rootfs full` on main branch:
```bash
if [ "$ROOTFS_FLAVOR" = "full" ] && [ "$GIT_BRANCH" = "main" ]; then
    log_error "main branch has no main_configuration/. Use --config-branch default or switch to a config branch"
    exit 1
fi
```

---

## Step 20: Commit all branches and push

```bash
git checkout popcat19-dev
git add -A
git commit -m "feat(popcat19-dev): scaffold personal config branch"
git push origin popcat19-dev

git checkout default
git add -A
git commit -m "feat(default): finalize daily driver defaults"
git push origin default

git checkout main
# (only the assemble-final.sh and system-configuration changes)
git add tools/build/assemble-final.sh flake_modules/
git commit -m "feat(main): add config-branch support and full-rootfs error"
git push origin main
```

---

## Sync Workflow (Post-Implementation)

```bash
# Base changes flow: dev → default → popcat19-dev
git checkout dev
# ... make base changes ...
git push origin dev

git checkout default
git rebase dev
git push origin default

git checkout popcat19-dev
git rebase default
# Resolve conflicts in personal files (user-config.nix, userprefs.conf, etc.)
git push origin popcat19-dev

# Stable release: popcat19-dev → popcat19
git checkout popcat19
git merge popcat19-dev
git push origin popcat19
```
