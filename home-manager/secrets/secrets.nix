let
  keys = import ../../secrets/keys.nix;
  users = [ keys.laptop keys.home ];
in
{
  "glm-token.age".publicKeys = users;
  "kimi-token.age".publicKeys = users;
  "minimax-token.age".publicKeys = users;
  "2233ai-token.age".publicKeys = users;
}
