{ inputs }:
let
  lib = inputs.nixpkgs.lib;
  system = "x86_64-linux";
  repoRoot = ../.;
  myLib = rec {
    secret = name: repoRoot + "/secrets/${name}";
    repoRelative = path:
      let
        rootStr = toString repoRoot + "/";
        pathStr = toString path;
      in
      assert builtins.isPath path && builtins.pathExists path && lib.hasPrefix rootStr pathStr;
      lib.removePrefix rootStr pathStr;
    mkRepoSymlink = hmConfig: configPath: path:
      if configPath != null
      then hmConfig.lib.file.mkOutOfStoreSymlink "${configPath}/${repoRelative path}"
      else path;
  };
in
{
  inherit system myLib;

  # An installed host: shared modules, then hosts/<name> with its profiles.
  # Existing callers can pass a name; other architectures pass { name; system; }.
  mkHost = host:
    let
      spec = if builtins.isString host then { name = host; } else host;
      hostSystem = spec.system or system;
    in
    lib.nixosSystem {
      specialArgs = { inherit inputs myLib; system = hostSystem; };
      modules = [
        ../modules
        ../hosts/${spec.name}
        {
          networking.hostName = spec.name;
          nixpkgs.hostPlatform = lib.mkDefault hostSystem;
        }
      ];
    };
}
