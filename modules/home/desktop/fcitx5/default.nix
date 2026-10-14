{ lib, pkgs, osConfig, ... }:
let
  mellowThemes = pkgs.fetchFromGitHub {
    owner = "sanweiya";
    repo = "fcitx5-mellow-themes";
    rev = "2c93b0ea3418a55c03f526d963c84a7ccde2c1e9";
    hash = "sha256-y7Q7BgObG99l0+8UVn24TibmUK3Xdq+/1N/G4o9eYAY=";
  };
  mellowThemeNames = lib.concatMap
    (color: [ "mellow-${color}" "mellow-${color}-dark" ])
    [ "graphite" "sakura" "vermilion" "wechat" "youlan" ];
in
{
  # Fcitx5 itself; engines and tools live in the imported modules.
  imports = [
    ./rime.nix
    ./xhup.nix
    ./vocotype.nix
    ./doubao.nix
    ./hotwords.nix
    ./vtype.nix
  ];

  config = lib.mkIf osConfig.my.desktop.enable {
    xdg.configFile = {
      # The Home Manager service owns Fcitx5; an XDG autostart instance could
      # otherwise acquire its D-Bus name first and survive package upgrades.
      "autostart/org.fcitx.Fcitx5.desktop".text = ''
        [Desktop Entry]
        Type=Application
        Name=Fcitx 5
        Hidden=true
      '';
      "fcitx5/profile" = {
        source = ./config/profile;
        force = true;
      };
      "fcitx5/conf/classicui.conf" = {
        source = ./config/classicui.conf;
        force = true;
      };
    };

    xdg.dataFile = lib.genAttrs (map (name: "fcitx5/themes/${name}") mellowThemeNames)
      (path: { source = "${mellowThemes}/${builtins.baseNameOf path}"; });

    i18n.inputMethod = {
      enable = true;
      type = "fcitx5";
      fcitx5.waylandFrontend = true;
      fcitx5.addons = with pkgs; [
        qt6Packages.fcitx5-configtool
        fcitx5-gtk
      ];
    };

    # DMS launches applications through systemd-run, which inherits the user
    # manager environment rather than niri's environment block. WeChat bundles
    # its Qt Fcitx module and needs this selection in either launch path.
    systemd.user.sessionVariables.QT_IM_MODULE = "fcitx";

    # Also handle an already-running desktop instance during the first handover.
    systemd.user.services.fcitx5-daemon.Unit.Conflicts = [ "app-org.fcitx.Fcitx5@autostart.service" ];
    systemd.user.services.fcitx5-daemon.Unit.After = [ "app-org.fcitx.Fcitx5@autostart.service" ];
  };
}
