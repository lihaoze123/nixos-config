{ inputs, pkgs-stable, system, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../base.nix
    inputs.ragenix.nixosModules.default
    inputs.home-manager.nixosModules.home-manager
    {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.users.chumeng = import ./home.nix;
      home-manager.extraSpecialArgs = { inherit inputs pkgs-stable system; };
      nixpkgs.overlays = [ inputs.claude-code.overlays.default ];
    }
    (import ../../modules)
    (import ../../overlays)
  ];
}
