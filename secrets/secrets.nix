let
  keys = import ./keys.nix;
  users = [ keys.laptop keys.home ];
in
{
    "dae-config.age".publicKeys = users;
    "hermes-env.age".publicKeys = users;
    "aria2-password.age".publicKeys = users;
    "edunet-env.age".publicKeys = users;
}
