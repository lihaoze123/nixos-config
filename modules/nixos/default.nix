{ inputs, pkgs-stable, system, ... }:
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
    users.chumeng.imports = [ ../home ];
    extraSpecialArgs = { inherit inputs pkgs-stable system; };
  };
}
