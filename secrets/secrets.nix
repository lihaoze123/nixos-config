let
  keys = import ./keys.nix;
  users = [ keys.laptop keys.home ];
in
{
  "dae-sub.age".publicKeys = users;
  "dae-config.age".publicKeys = users;
}
