let
  keys = import ./keys.nix;
  users = [ keys.laptop keys.home ];
in
{
}
