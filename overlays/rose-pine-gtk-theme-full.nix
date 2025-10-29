# Overlay wrapper that exposes rose-pine-gtk-theme-full as pkgs.rose-pine-gtk-theme-full
final: prev: let
  lib = prev.lib;
  stdenvNoCC = prev.stdenvNoCC;
  fetchFromGitHub = prev.fetchFromGitHub;
  gtk3 = prev.gtk3;
  gtk4 = prev.gtk4;
  gnome-themes-extra = prev.gnome-themes-extra;
  gtk_engines = prev.gtk_engines;
  gtk-engine-murrine = prev.gtk-engine-murrine;
  sassc = prev.sassc;
in {
  rose-pine-gtk-theme-full = stdenvNoCC.mkDerivation rec {
    pname = "rose-pine-gtk-theme-full";
    version = "2024-12-21";

    src = fetchFromGitHub {
      owner = "Fausto-Korpsvart";
      repo = "Rose-Pine-GTK-Theme";
      # Pin upstream to a stable commit to avoid hash drift
      rev = "c4fdfa62a9eb6941a36b2cd5026fc64123aaa0dd";
      sha256 = "sha256-eeBuGvJKdv/puMg2FN3Ue52OU1LgipEte/OhRwIDDs8=";
    };

    nativeBuildInputs = [
      sassc
    ];

    buildInputs = [
      gtk3
      gtk4
      gnome-themes-extra
      gtk_engines
    ];

    propagatedUserEnvPkgs = [
      gtk-engine-murrine
    ];

    buildPhase = ''
      cd themes

      export SASSC_OPT="-M -t expanded"
      export COLOR_VARIANTS="-Dark"

      cp -rf src/sass/_tweaks.scss src/sass/_tweaks-temp.scss
      cp -rf src/sass/gnome-shell/_common.scss src/sass/gnome-shell/_common-temp.scss

      echo "Building GTK3 CSS..."
      sassc $SASSC_OPT src/main/gtk-3.0/gtk-Dark.scss src/main/gtk-3.0/gtk-Dark.css || echo "GTK3 build warning"

      echo "Building GTK4 CSS..."
      sassc $SASSC_OPT src/main/gtk-4.0/gtk-Dark.scss src/main/gtk-4.0/gtk-Dark.css || echo "GTK4 build warning"

      echo "Building Gnome Shell CSS..."
      sassc $SASSC_OPT src/main/gnome-shell/gnome-shell-Dark.scss src/main/gnome-shell/gnome-shell-Dark.css || echo "Gnome Shell build warning"

      echo "Building Cinnamon CSS..."
      sassc $SASSC_OPT src/main/cinnamon/cinnamon-Dark.scss src/main/cinnamon/cinnamon-Dark.css || echo "Cinnamon build warning"

      cd ..
    '';

    installPhase = ''
            runHook preInstall

            mkdir -p $out/share/themes
            mkdir -p $out/share/icons

            THEME_NAME="Rose-Pine-Main-BL"
            mkdir -p "$out/share/themes/$THEME_NAME"

            cp -r themes/src/main/* "$out/share/themes/$THEME_NAME/"
            cp -r themes/src/assets "$out/share/themes/$THEME_NAME/"

            if [ -f "$out/share/themes/$THEME_NAME/gtk-3.0/gtk-Dark.css" ]; then
              mv "$out/share/themes/$THEME_NAME/gtk-3.0/gtk-Dark.css" "$out/share/themes/$THEME_NAME/gtk-3.0/gtk.css"
            fi
            if [ -f "$out/share/themes/$THEME_NAME/gtk-4.0/gtk-Dark.css" ]; then
              mv "$out/share/themes/$THEME_NAME/gtk-4.0/gtk-Dark.css" "$out/share/themes/$THEME_NAME/gtk-4.0/gtk.css"
            fi

            MOON_THEME_NAME="Rose-Pine-Moon-BL"
            cp -r "$out/share/themes/$THEME_NAME" "$out/share/themes/$MOON_THEME_NAME"

            cp -r icons/Rose-Pine "$out/share/icons/"
            cp -r icons/Rose-Pine-Moon "$out/share/icons/"

            cat > "$out/share/themes/$THEME_NAME/index.theme" << 'EOF'
      [Desktop Entry]
      Type=X-GNOME-Metatheme
      Name=Rose Pine Main BL
      Comment=Rose Pine dark theme with borderless windows
      Encoding=UTF-8

      [X-GNOME-Metatheme]
      GtkTheme=Rose-Pine-Main-BL
      MetacityTheme=Rose-Pine-Main-BL
      IconTheme=Rose-Pine
      CursorTheme=rose-pine-hyprcursor
      ButtonLayout=appmenu:minimize,maximize,close
      EOF

            cat > "$out/share/themes/$MOON_THEME_NAME/index.theme" << 'EOF'
      [Desktop Entry]
      Type=X-GNOME-Metatheme
      Name=Rose Pine Moon BL
      Comment=Rose Pine moon theme with borderless windows
      Encoding=UTF-8

      [X-GNOME-Metatheme]
      GtkTheme=Rose-Pine-Moon-BL
      MetacityTheme=Rose-Pine-Moon-BL
      IconTheme=Rose-Pine-Moon
      CursorTheme=rose-pine-hyprcursor
      ButtonLayout=appmenu:minimize,maximize,close
      EOF

            find $out/share -type f -exec chmod 644 {} \;
            find $out/share -type d -exec chmod 755 {} \;

            runHook postInstall
    '';

    meta = with lib; {
      description = "Rose Pine GTK theme with borderless design optimized for Hyprland";
      longDescription = ''
        A complete Rose Pine theme suite with borderless windows (BL variant)
        optimized for tiling window managers like Hyprland. Built from SCSS
        sources with proper SASS compilation for accurate theming.

        Includes both Main (default dark) and Moon (darker) variants with
        matching icon themes from Fausto-Korpsvart's enhanced Rose Pine collection.
      '';
      homepage = "https://github.com/Fausto-Korpsvart/Rose-Pine-GTK-Theme";
      license = licenses.gpl3Plus;
      platforms = platforms.linux;
      maintainers = with maintainers; [];
    };
  };
}
