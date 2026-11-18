{ lib, ... }:
{
  options.my.shell.fish.profile = lib.mkOption {
    type = lib.types.enum [ "full" "minimal" ];
    default = "full";
    description = "Fish profile; minimal keeps Starship and zoxide but omits Atuin and nix-index/comma.";
  };

  config.my.home = ./home.nix;
}
