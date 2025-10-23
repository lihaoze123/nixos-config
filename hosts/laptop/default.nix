{ inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../base.nix
    inputs.ragenix.nixosModules.default
    inputs.home-manager.nixosModules.home-manager
    {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.users.chumeng = import ./laptop.nix;
      home-manager.extraSpecialArgs = inputs;
    }
    (import ../../modules)
    (import ../../overlays)
  ];
}
