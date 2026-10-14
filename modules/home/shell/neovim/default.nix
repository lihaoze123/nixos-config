{ config, pkgs, osConfig, ... }:
let
  inherit (osConfig.my) configPath;
in
{
  # Link the live checkout when there is one, so plugin updates stay editable.
  xdg.configFile."nvim".source =
    if configPath != null
    then config.lib.file.mkOutOfStoreSymlink "${configPath}/modules/home/shell/neovim/nvim"
    else ./nvim;
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
      pkgs.clang-tools
    ];
  };
}
