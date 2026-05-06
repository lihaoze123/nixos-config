let
  keys = import ../../secrets/keys.nix;
  users = [ keys.laptop keys.home ];
in
{
  "glm-token.age".publicKeys = users;
  "kimi-token.age".publicKeys = users;
  "minimax-token.age".publicKeys = users;
  "codex-cpa-token.age".publicKeys = users;
  "deepseek-token.age".publicKeys = users;
}
