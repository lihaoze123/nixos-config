{ inputs }:
let
  system = "x86_64-linux";
in
{
  inherit system;

  # An installed host: shared modules, then hosts/<name> with its profiles.
  # Existing callers can pass a name; other architectures pass { name; system; }.
  mkHost = host:
    let
      spec = if builtins.isString host then { name = host; } else host;
      hostSystem = spec.system or system;
    in
    inputs.nixpkgs.lib.nixosSystem {
      specialArgs = { inherit inputs; system = hostSystem; };
      modules = [
        ../modules/nixos
        ../hosts/${spec.name}
        {
          networking.hostName = spec.name;
          nixpkgs.hostPlatform = inputs.nixpkgs.lib.mkDefault hostSystem;
        }
      ];
    };
}
