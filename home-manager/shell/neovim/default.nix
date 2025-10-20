{ config, pkgs, ... }: let
    nvimPath = "${config.home.homeDirectory}/nixos-config/home-manager/shell/neovim/nvim";
in
{
    xdg.configFile."nvim".source = config.lib.file.mkOutOfStoreSymlink nvimPath;
    programs.neovim = {
        enable = true;
        withNodeJs = true;
        withPython3 = true;
    };
    programs.neovide.enable = true;
}
