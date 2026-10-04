{ config, pkgs, ... }:
let
  nvimPath = "${config.home.homeDirectory}/nixos-config/home-manager/shell/neovim/nvim";
in
{
  xdg.configFile."nvim".source = config.lib.file.mkOutOfStoreSymlink nvimPath;
  programs.neovim = {
    enable = true;
    # Keep the live ./nvim directory; load Home Manager's init code via the wrapper.
    sideloadInitLua = true;
    withNodeJs = true;
    withPython3 = true;
    withRuby = true;
  };
  programs.neovide.enable = true;
}
