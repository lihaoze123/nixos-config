{ lib, pkgs, inputs, osConfig, ... }:
let
  # WeChat Pinyin; wetype-setup downloads the engine into the user directory.
  vtype = inputs.nur-packages.packages.${pkgs.stdenv.hostPlatform.system}.vtype-linux;
in
lib.mkIf (osConfig.my.desktop.enable && osConfig.my.input.vtype.enable) {
  home.packages = [ vtype ];
  # After VoCoType (mkAfter), keeping the original addon order.
  i18n.inputMethod.fcitx5.addons = lib.mkOrder 1600 [ vtype ];
}
