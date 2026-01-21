# Key Bindings Configuration
#
# Purpose: Configure keyboard shortcuts and mouse bindings for Hyprland
# Dependencies: userConfig.defaultApps
# Related: window-rules.nix
#
# This module:
# - Defines modifier keys and application variables
# - Configures system and window management shortcuts
# - Sets up application launchers and utilities
# - Binds media, volume, and brightness controls
{ userConfig, ... }:
{
  wayland.windowManager.hyprland.settings = {
    "$mainMod" = "SUPER";
    "$term" = userConfig.defaultApps.terminal.command;
    "$editor" = userConfig.defaultApps.editor.command;
    "$file" = userConfig.defaultApps.fileManager.command;
    "$browser" = userConfig.defaultApps.browser.command;
    "$menu" = "${userConfig.defaultApps.launcher.command} --dmenu";
    "$launcher" = userConfig.defaultApps.launcher.command;

    bind = [
      # cat: System Close
      # desc: Close current window
      "$mainMod, Q, killactive"
      "Alt, F4, killactive"
      # desc: Kill Hyprland compositor
      "$mainMod+Ctrl, Q, exec, hyprctl kill"
      # desc: Exit Hyprland
      "$mainMod, Delete, exit"
      # desc: Lock screen
      "$mainMod, L, exec, hyprlock"

      # cat: Window State
      # desc: Toggle floating mode
      "$mainMod, W, togglefloating"
      # desc: Toggle window grouping
      "$mainMod, G, togglegroup"
      # desc: Toggle fullscreen
      "Alt, Return, fullscreen"
      # desc: Toggle split mode
      "$mainMod, J, togglesplit"

      # cat: Launchers
      # desc: Open terminal
      "$mainMod, T, exec, $term"
      # desc: Open file manager
      "$mainMod, E, exec, $file"
      # desc: Open editor
      "$mainMod, C, exec, $editor"
      # desc: Open browser
      "$mainMod, F, exec, $browser"
      # desc: Open Vicinae
      "$mainMod, A, exec, vicinae open"
      # desc: Open application launcher
      "$mainMod+Shift, A, exec, fuzzel"
      # desc: Pick color from screen
      "$mainMod+Shift, C, exec, hyprpicker -a"
      # desc: Open clipboard history
      "$mainMod, V, exec, vicinae vicinae://extensions/vicinae/clipboard/history"
      # desc: Paste from clipboard history
      "$mainMod+Shift, V, exec, bash -lc \"cliphist list | fuzzel --dmenu --with-nth 2 | cliphist decode | wl-copy && sleep 0.05 && wtype -M ctrl -k v\""
      # desc: Restart hyprpanel
      "Ctrl+Alt, W, exec, systemctl --user restart hyprpanel.service"
      # desc: Restart Noctalia shell
      "$mainMod+Ctrl, N, exec, systemctl --user restart noctalia-shell.service"

      # cat: Screenshots
      # desc: Screenshot monitor
      "$mainMod, P, exec, ~/.local/bin/screenshot monitor"
      # desc: Screenshot monitor (keep shader)
      "$mainMod+Ctrl, P, exec, ~/.local/bin/screenshot monitor --keep-shader"
      # desc: Screenshot region
      "$mainMod+Shift, P, exec, ~/.local/bin/screenshot region"
      # desc: Screenshot region (keep shader)
      "$mainMod+Shift+Ctrl, P, exec, ~/.local/bin/screenshot region --keep-shader"

      # cat: Media
      # desc: Play/pause media
      ",XF86AudioPlay, exec, playerctl play-pause"
      ",XF86AudioPause, exec, playerctl play-pause"
      # desc: Next track
      ",XF86AudioNext, exec, playerctl next"
      # desc: Previous track
      ",XF86AudioPrev, exec, playerctl previous"
      # desc: Stop media
      ",XF86AudioStop, exec, playerctl stop"
      "Alt, F8, exec, playerctl play-pause"
      "Alt, F6, exec, playerctl previous"
      "Alt, F7, exec, playerctl next"

      # cat: Focus
      # desc: Focus window left
      "$mainMod, Left, movefocus, l"
      # desc: Focus window right
      "$mainMod, Right, movefocus, r"
      # desc: Focus window up
      "$mainMod, Up, movefocus, u"
      # desc: Focus window down
      "$mainMod, Down, movefocus, d"
      # desc: Cycle through windows
      "Alt, Tab, movefocus, d"

      # cat: Group Navigation
      # desc: Move to previous group
      "$mainMod+Ctrl, H, changegroupactive, b"
      # desc: Move to next group
      "$mainMod+Ctrl, L, changegroupactive, f"

      # cat: Workspace
      # desc: Switch to workspace 1-10
      "$mainMod, 1, workspace, 1"
      "$mainMod, 2, workspace, 2"
      "$mainMod, 3, workspace, 3"
      "$mainMod, 4, workspace, 4"
      "$mainMod, 5, workspace, 5"
      "$mainMod, 6, workspace, 6"
      "$mainMod, 7, workspace, 7"
      "$mainMod, 8, workspace, 8"
      "$mainMod, 9, workspace, 9"
      "$mainMod, 0, workspace, 10"

      # desc: Switch to previous/next workspace
      "$mainMod+Ctrl, Right, workspace, r+1"
      "$mainMod+Ctrl, Left, workspace, r-1"
      # desc: Switch to empty workspace
      "$mainMod+Ctrl, Down, workspace, empty"

      # cat: Move to Workspace
      # desc: Move window to workspace 1-10
      "$mainMod+Shift, 1, movetoworkspace, 1"
      "$mainMod+Shift, 2, movetoworkspace, 2"
      "$mainMod+Shift, 3, movetoworkspace, 3"
      "$mainMod+Shift, 4, movetoworkspace, 4"
      "$mainMod+Shift, 5, movetoworkspace, 5"
      "$mainMod+Shift, 6, movetoworkspace, 6"
      "$mainMod+Shift, 7, movetoworkspace, 7"
      "$mainMod+Shift, 8, movetoworkspace, 8"
      "$mainMod+Shift, 9, movetoworkspace, 9"
      "$mainMod+Shift, 0, movetoworkspace, 10"

      # desc: Move window to next/prev workspace
      "$mainMod+Ctrl+Alt, Right, movetoworkspace, r+1"
      "$mainMod+Ctrl+Alt, Left, movetoworkspace, r-1"

      # desc: Move window to workspace 1-10 (silent)
      "$mainMod+Alt, 1, movetoworkspacesilent, 1"
      "$mainMod+Alt, 2, movetoworkspacesilent, 2"
      "$mainMod+Alt, 3, movetoworkspacesilent, 3"
      "$mainMod+Alt, 4, movetoworkspacesilent, 4"
      "$mainMod+Alt, 5, movetoworkspacesilent, 5"
      "$mainMod+Alt, 6, movetoworkspacesilent, 6"
      "$mainMod+Alt, 7, movetoworkspacesilent, 7"
      "$mainMod+Alt, 8, movetoworkspacesilent, 8"
      "$mainMod+Alt, 9, movetoworkspacesilent, 9"
      "$mainMod+Alt, 0, movetoworkspacesilent, 10"

      # cat: Move Window
      # desc: Move window left
      "$mainMod+Shift+Ctrl, Left, exec, bash -c 'if grep -q \"true\" <<< $(hyprctl activewindow -j | jq -r .floating); then hyprctl dispatch moveactive -30 0; else hyprctl dispatch movewindow l; fi'"
      # desc: Move window right
      "$mainMod+Shift+Ctrl, Right, exec, bash -c 'if grep -q \"true\" <<< $(hyprctl activewindow -j | jq -r .floating); then hyprctl dispatch moveactive 30 0; else hyprctl dispatch movewindow r; fi'"
      # desc: Move window up
      "$mainMod+Shift+Ctrl, Up, exec, bash -c 'if grep -q \"true\" <<< $(hyprctl activewindow -j | jq -r .floating); then hyprctl dispatch moveactive 0 -30; else hyprctl dispatch movewindow u; fi'"
      # desc: Move window down
      "$mainMod+Shift+Ctrl, Down, exec, bash -c 'if grep -q \"true\" <<< $(hyprctl activewindow -j | jq -r .floating); then hyprctl dispatch moveactive 0 30; else hyprctl dispatch movewindow d; fi'"

      # cat: Workspace (Mouse)
      # desc: Scroll to change workspace
      "$mainMod, mouse_down, workspace, e+1"
      "$mainMod, mouse_up, workspace, e-1"

      # cat: Special Workspace
      # desc: Move window to special workspace
      "$mainMod+Alt, S, movetoworkspacesilent, special"
      # desc: Toggle special workspace
      "$mainMod, S, togglespecialworkspace"

      # cat: Debug
      # desc: Inspect layer surfaces
      "$mainMod+Shift, N, exec, sh -c 'hyprctl layers > ~/hyprctl-layer-out.txt && $term $editor ~/hyprctl-layer-out.txt'"
    ];

    binde = [
      # cat: Resize
      # desc: Resize window right
      "$mainMod+Shift, Right, resizeactive, 30 0"
      # desc: Resize window left
      "$mainMod+Shift, Left, resizeactive, -30 0"
      # desc: Resize window up
      "$mainMod+Shift, Up, resizeactive, 0 -30"
      # desc: Resize window down
      "$mainMod+Shift, Down, resizeactive, 0 30"
    ];

    bindel = [
      # cat: Volume
      # desc: Volume up (F12)
      ",F12, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 4%+"
      # desc: Volume down (F11)
      ",F11, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 4%-"
      # desc: Toggle mute (F10)
      ",F10, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
      # desc: Volume up (media key)
      ",XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 4%+"
      # desc: Volume down (media key)
      ",XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 4%-"
      # desc: Toggle mute (media key)
      ",XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
      # desc: Toggle microphone mute
      ",XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"

      # cat: Brightness
      # desc: Brightness up
      ",XF86MonBrightnessUp, exec, brightnessctl s 10%+"
      # desc: Brightness down
      ",XF86MonBrightnessDown, exec, brightnessctl s 10%-"
    ];

    bindm = [
      # cat: Mouse
      # desc: Move window with mouse
      "$mainMod, mouse:272, movewindow"
      # desc: Resize window with mouse
      "$mainMod, mouse:273, resizewindow"
      # desc: Move window mode toggle
      "$mainMod, Z, movewindow"
      # desc: Resize window mode toggle
      "$mainMod, X, resizewindow"
    ];
  };
}
