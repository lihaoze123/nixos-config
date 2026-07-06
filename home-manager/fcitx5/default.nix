{ pkgs, ... }:
let
  rime-shuangpin-fuzhuma-version = "1.0.8";
  rime-shuangpin-fuzhuma-src = pkgs.fetchzip {
    url = "https://github.com/gaboolic/rime-shuangpin-fuzhuma/releases/download/${rime-shuangpin-fuzhuma-version}/rime-moqi-schemas.zip";
    hash = "sha256-WNXLexWBdgqMsHxw8Cp1yZB85HxZ4VmfX5f86sfCfHY=";
    stripRoot = false;
  };

  rime-shuangpin-fuzhuma = pkgs.stdenvNoCC.mkDerivation {
    pname = "rime-shuangpin-fuzhuma";
    version = rime-shuangpin-fuzhuma-version;
    dontUnpack = true;
    installPhase = ''
      runHook preInstall

      mkdir -p $out/share/rime-data
      cp -r ${rime-shuangpin-fuzhuma-src}/. $out/share/rime-data/
      cp ${pkgs.rime-data}/share/rime-data/stroke.* $out/share/rime-data/

      runHook postInstall
    '';
  };
in
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
          rime-shuangpin-fuzhuma
        ];
      })
      qt6Packages.fcitx5-configtool
      fcitx5-gtk
    ];
  };
}
