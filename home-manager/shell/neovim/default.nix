{ config, pkgs, pkgs-stable, ... }:
let
  nvimPath = "${config.home.homeDirectory}/nixos-config/home-manager/shell/neovim/nvim";
in
{
  xdg.configFile."nvim".source = config.lib.file.mkOutOfStoreSymlink nvimPath;
  programs.neovim = {
    enable = true;
    # Keep the live ./nvim directory; load Home Manager's init code via the wrapper.
    sideloadInitLua = true;
    withNodeJs = false;
    withPython3 = false;
    withRuby = false;
    # Only on Neovim's PATH: nvim-treesitter (main) builds parsers with the
    # tree-sitter CLI and a C compiler, Mason installs npm-based servers, and
    # CompetiTest compiles C++. Make sure clangd is not installed by Mason.
    extraPackages = [
      pkgs.tree-sitter
      pkgs.gcc
      pkgs.nodejs
      pkgs-stable.clang-tools # https://github.com/nixos/nixpkgs/issues/463367
    ];
  };
}
