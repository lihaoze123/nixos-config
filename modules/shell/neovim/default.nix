{ lib, ... }:
{
  options.my.shell.neovim.profile = lib.mkOption {
    type = lib.types.enum [ "full" "minimal" ];
    default = "full";
    description = "Neovim profile; minimal ships a basic init without LazyVim or its development tools.";
  };

  config.my.home = ./home.nix;
}
