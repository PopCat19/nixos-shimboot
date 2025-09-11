{pkgs, ...}: {
  home.packages = with pkgs; [
    universal-android-debloater
    android-tools
    scrcpy
  ];
}
