{ inputs, pkgs-stable, system, ... }:

# Minimal system for a new machine: boot, network, user, SSH, shell and editor.
# Every my.features option keeps its default (off); enable them in ./features.nix.
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
      home-manager.users.chumeng = import ../../home-manager/home.nix;
      home-manager.extraSpecialArgs = { inherit inputs pkgs-stable system; };
    }
    (import ../../modules)
    (import ../../overlays)
  ];

  # Distinct from the `nixos` alias, which points to laptop.
  networking.hostName = "base";
}
