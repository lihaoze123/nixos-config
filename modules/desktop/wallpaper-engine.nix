{ config, lib, pkgs, ... }:
let
  cfg = config.my.desktop.wallpaperEngine;
  wallpaperEngineSrc = pkgs.fetchFromGitHub {
    owner = "sgtaziz";
    repo = "dms-wallpaperengine";
    rev = "e96718f5038f54546311a239ef0f6622f15c515a";
    hash = "sha256-SSNXZl7DFA7cKaSt4FaXcQ58IjcHxvyi/zVKMwvHXdQ=";
  };
  wallpaperEngine = pkgs.runCommand "dms-wallpaperengine" { } ''
    cp -r ${wallpaperEngineSrc} $out
    chmod -R u+w $out
    # Use store paths even when DMS still has the previous session's PATH.
    substituteInPlace $out/js/CommandBuilder.js $out/ui/ScenePropertiesModal.qml \
      --replace-fail '["linux-wallpaperengine"' '["${pkgs.linux-wallpaperengine}/bin/linux-wallpaperengine"'
    substituteInPlace $out/LinuxWallpaperEnginePlugin.qml \
      --replace-fail '["magick",' '["${pkgs.imagemagick}/bin/magick",' \
      --replace-fail 'command -v magick' 'test -x ${pkgs.imagemagick}/bin/magick'
  '';
in
{
  options.my.desktop.wallpaperEngine.enable = lib.mkEnableOption "Wallpaper Engine animated wallpapers with the DMS plugin";

  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = !cfg.enable || config.my.desktop.enable;
          message = "my.desktop.wallpaperEngine requires my.desktop";
        }
      ];
    }
    (lib.mkIf cfg.enable {
      my.desktop.dms.plugins.linuxWallpaperEngine.source = wallpaperEngine;
      my.home = lib.setDefaultModuleLocation ./wallpaper-engine.nix {
        home.packages = [
          pkgs.linux-wallpaperengine
          pkgs.imagemagick
        ];
        xdg.configFile."niri/wallpaper-engine.kdl".text = ''
          // Show animated wallpapers on the desktop and within the overview backdrop.
          layout {
              background-color "transparent"
          }

          layer-rule {
              match namespace="^linux-wallpaperengine$"
              place-within-backdrop true
          }
        '';
      };
    })
  ];
}
