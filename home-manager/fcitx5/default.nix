{ pkgs, ... }:
{
  xdg.configFile = {
    "fcitx5/profile" = {
      source = ./profile;
      force = true;
    };
  };
  home.file.".local/share/fcitx5/rime/default.custom.yaml".source = ./default.custom.yaml;

  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5.waylandFrontend = true;
    fcitx5.addons = with pkgs; [
      (fcitx5-rime.override {
        rimeDataPkgs = [
          pkgs.rime-ice
        ];
      })
      qt6Packages.fcitx5-configtool
      fcitx5-gtk
    ];
  };
}
