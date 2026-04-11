let
  keys = import ./keys.nix;
  users = [ keys.laptop keys.home ];
in
{
    "dae-config.age".publicKeys = users;
    "hermes-env.age".publicKeys = users;
}
