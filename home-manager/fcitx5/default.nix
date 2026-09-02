{ config
, lib
, pkgs
, ...
}:
let
  rime-crane-rev = "44d00fa68d9f4754b6381797bdbd5fcd405bfaf7";
  rime-user-dictionaries = {
    "xhup.user.dict.yaml" = ./xhup.user.dict.yaml;
    "xhup.user.chat.dict.yaml" = ./xhup.user.chat.dict.yaml;
    "xhup.user.coding.dict.yaml" = ./xhup.user.coding.dict.yaml;
    "xhup.user.work.dict.yaml" = ./xhup.user.work.dict.yaml;
  };
  rime-crane-config-id = builtins.hashString "sha256" ''
    ${rime-crane-rev}
    ${builtins.readFile ./default.custom.yaml}
    ${lib.concatStringsSep "\n" (
      lib.mapAttrsToList (_: path: builtins.readFile path) rime-user-dictionaries
    )}
  '';
  rime-crane-src = pkgs.fetchFromGitHub {
    owner = "kchen0x";
    repo = "rime-crane";
    rev = rime-crane-rev;
    hash = "sha256-OZgbU/ZaHsrMnZfHp7r3sNxmPwZ/SFlKKKjKx9w4r7s=";
  };

  rime-crane = pkgs.stdenvNoCC.mkDerivation {
    pname = "rime-crane";
    version = builtins.substring 0 7 rime-crane-rev;
    dontUnpack = true;
    installPhase = ''
      runHook preInstall

      mkdir -p $out/share/rime-data
      cp -r ${rime-crane-src}/. $out/share/rime-data/
      substituteInPlace $out/share/rime-data/xhup.dict.yaml \
        --replace-fail \
          '  - "xhup_dicts/xhup.user"              # 用户码表' \
          '  - "xhup_dicts/xhup.user"              # 通用用户码表
        - "xhup_dicts/xhup.user.work"         # 工作词库
        - "xhup_dicts/xhup.user.coding"       # 编程词库
        - "xhup_dicts/xhup.user.chat"         # 聊天词库'

      runHook postInstall
    '';
  };

  fcitx5-rime-crane = pkgs.fcitx5-rime.override {
    rimeDataPkgs = [ rime-crane ];
  };

  rime-user-data-dir = "${config.home.homeDirectory}/.local/share/fcitx5/rime";
  rime-user-dictionary-dir = "${config.home.homeDirectory}/nixos-config/home-manager/fcitx5";
in
{
  xdg.configFile = {
    "fcitx5/profile" = {
      source = ./profile;
      force = true;
    };
  };
  home.file = {
    ".local/share/fcitx5/rime/default.custom.yaml".source = ./default.custom.yaml;

    # Files in the Nix store have a fixed mtime, so Rime cannot notice that
    # their contents changed. Invalidate only the generated deployment state
    # when either the upstream revision or our customization changes.
    ".local/share/fcitx5/rime/.rime-crane-config-id" = {
      text = rime-crane-config-id;
      onChange = ''
        rime_user_data_dir=${lib.escapeShellArg rime-user-data-dir}
        run rm -rf -- "$rime_user_data_dir/build"
        run rm -f -- "$rime_user_data_dir/user.yaml"
      '';
    };
  };

  xdg.dataFile = lib.mapAttrs' (
    name: _:
    lib.nameValuePair "fcitx5/rime/xhup_dicts/${name}" {
      source = config.lib.file.mkOutOfStoreSymlink "${rime-user-dictionary-dir}/${name}";
      force = true;
    }
  ) rime-user-dictionaries;

  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5.waylandFrontend = true;
    fcitx5.addons = with pkgs; [
      fcitx5-rime-crane
      qt6Packages.fcitx5-configtool
      fcitx5-gtk
    ];
  };

  # Restart Fcitx5 after cache invalidation so Rime deploys the new schema
  # before it handles the next input event.
  systemd.user.services.fcitx5-daemon.Unit.X-Restart-Triggers = [ rime-crane-config-id ];
}
