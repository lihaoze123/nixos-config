{ inputs }:
let
  system = "x86_64-linux";
in
{
  inherit system;

  # An installed host: shared modules, then hosts/<name> with its profiles.
  mkHost = name: inputs.nixpkgs.lib.nixosSystem {
    specialArgs = { inherit inputs system; };
    modules = [
      ../modules/nixos
      ../hosts/${name}
      { networking.hostName = name; }
    ];
  };
}
