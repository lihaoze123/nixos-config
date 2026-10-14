let
  keys = import ./keys.nix;
  # Host keys decrypt system secrets; user keys decrypt Home Manager secrets.
  users = [ keys.laptop keys.laptop-host keys.home keys.class keys.class-user ];
  homeUsers = [ keys.laptop keys.home keys.class-user ];
in
{
  "dae-nodes.age".publicKeys = users;
  "hermes-env.age".publicKeys = users;
  "aria2-password.age".publicKeys = users;
  "edunet-env.age".publicKeys = users;
  "doubao-asr.age".publicKeys = users;
  "r2-cache-credentials.age".publicKeys = users;
  "deepseek-token.age".publicKeys = users;

  "glm-token.age".publicKeys = homeUsers;
  "kimi-token.age".publicKeys = homeUsers;
  "minimax-token.age".publicKeys = homeUsers;
  "codex-cpa-token.age".publicKeys = homeUsers;
}
