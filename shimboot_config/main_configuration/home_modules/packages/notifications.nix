{pkgs, ...}: {
  home.packages = with pkgs; [
    libnotify
    zenity
  ];
}
