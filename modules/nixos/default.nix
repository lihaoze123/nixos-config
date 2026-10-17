{ config, lib, pkgs, inputs, system, ... }:
{
  # Shared by every installed host; mkHost adds the host directory.
  imports = [
    ../options.nix
    inputs.ragenix.nixosModules.default
    inputs.home-manager.nixosModules.home-manager
    ./core.nix
    ./nix-cache.nix
    ./overlays.nix
    ./desktop
    ./hardware
    ./network
    ./services/aria2.nix
    ./virtualisation.nix
    ./programs.nix
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    # Applications can replace managed symlinks with regular files. Keep every
    # displaced version without letting an existing .backup block activation.
    backupCommand = lib.mkDefault (pkgs.writeShellScript "home-manager-backup" ''
      set -eu
      exec ${pkgs.coreutils}/bin/mv --backup=numbered --no-target-directory -- "$1" "$1.backup"
    '');
    users.${config.my.user.name}.imports = [ ../home ] ++ config.my.home.imports;
    extraSpecialArgs = { inherit inputs system; };
  };
}
