{ inputs, pkgs-stable, system, ... }:

{
  imports = [
    ./features.nix
    ./hardware-configuration.nix
    ../base.nix
    inputs.ragenix.nixosModules.default
    inputs.home-manager.nixosModules.home-manager
    {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.users.chumeng = import ./class.nix;
      home-manager.extraSpecialArgs = { inherit inputs pkgs-stable system; };
    }
    (import ../../modules)
    (import ../../overlays)
  ];

  networking.hostName = "class";

  # Dank Greeter output, matching config-class.kdl.
  my.niri.greeterExtraConfig = ''
    output "eDP-1" {
        mode "1980x1080@60.0"
        scale 1.2
    }
  '';
}
