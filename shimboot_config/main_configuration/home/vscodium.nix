# VSCodium Configuration Module
#
# Purpose: Configure VSCodium code editor with stylix theming and essential extensions
# Dependencies: vscodium, stylix, vscode-extensions
# Related: stylix.nix, editors.nix, packages.nix
#
# This module:
# - Enables VSCodium editor with essential extensions
# - Integrates with Stylix for automatic theming
# - Configures useful user settings and preferences
# - Includes development tools and language support extensions
{ pkgs, ... }:
{
  # Enable VSCodium with extensions
  programs.vscode = {
    enable = true;
    package = pkgs.vscodium;

    # Essential extensions for development
    profiles.default.extensions = with pkgs.vscode-extensions; [
      # Nix language support
      jnoortheen.nix-ide

      # XML and YAML support
      redhat.vscode-xml
      redhat.vscode-yaml

      # Rust development
      rust-lang.rust-analyzer
    ];

    # User settings - avoiding font/theme conflicts with Stylix
    profiles.default.userSettings = {
      # Editor behavior
      "editor.minimap.enabled" = true;
      "editor.minimap.renderCharacters" = true;

      # File handling
      "files.autoSave" = "onFocusChange";
      "files.autoSaveDelay" = 1000;
      "files.trimTrailingWhitespace" = true;
      "files.insertFinalNewline" = true;
      "files.trimFinalNewlines" = true;
      "files.watcherExclude" = {
        "**/.git/objects/**" = true;
        "**/.git/subtree-cache/**" = true;
        "**/node_modules/*/**" = true;
        "**/.hg/store/**" = true;
        "**/target/debug/**" = true;
      };

      # Theme and layout
      "workbench.colorTheme" = "Stylix";
      "workbench.preferredDarkColorTheme" = "Stylix";
      "workbench.preferredLightColorTheme" = "Stylix";
      "workbench.activityBar.location" = "bottom";

      # Terminal settings
      "terminal.integrated.defaultProfile.linux" = "fish";

      # Git settings
      "git.autofetch" = true;
      "git.confirmSync" = false;
      "git.enableSmartCommit" = true;
      "git.enableCommitSigning" = true;

      # Extensions settings
      "extensions.experimental.affinity" = {
        "ms-vscode.vscode-typescript-next" = 1;
        "ms-vscode.vscode-json" = 1;
        "vscode.yaml" = 1;
      };

      # Disable auto-write features
      # "extensions.autoUpdate" = false;
      # "extensions.autoCheckUpdates" = false;
      # "workbench.settings.editor" = "json";

      # Nix-IDE specific settings
      "nix.enableLanguageServer" = true;
      "nix.formatterPath" = "nixfmt";
      "nix.serverPath" = "nixd";

      # Security
      "security.workspace.trust.enabled" = true;
      "security.workspace.trust.startupPrompt" = "never";
      "security.workspace.trust.untrustedFiles" = "open";

      # Telemetry
      "redhat.telemetry.enabled" = false;
    };
  };

  # Note: VSCodium package is already included in editors.nix
}
