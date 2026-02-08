{ pkgs, ... }:

{
  home.packages = [ pkgs.antigravity-tools ];

  xdg.desktopEntries.antigravity-tools = {
    name = "Antigravity Tools";
    comment = "Antigravity account manager";
    exec = "${pkgs.antigravity-tools}/bin/antigravity-tools";
    icon = "${pkgs.antigravity-tools-unwrapped}/share/icons/hicolor/128x128/apps/antigravity_tools.png";
    terminal = false;
    type = "Application";
    categories = [ "Network" "Utility" ];
  };
}
