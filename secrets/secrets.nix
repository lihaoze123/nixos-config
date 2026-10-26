let
  keys = import ./keys.nix;
  # Host keys decrypt system secrets; user keys decrypt Home Manager secrets.
  users = [ keys.laptop keys.laptop-host keys.home keys.class keys.class-user ];
  homeUsers = [ keys.laptop keys.home keys.class-user ];
in
{
  "cloudreve-admin-password.age".publicKeys = [ keys.vps keys.laptop keys.class-user ];
  "wastebin-env.age".publicKeys = [ keys.vps keys.laptop keys.class-user ];
  "media-credentials.age".publicKeys = [ keys.vps keys.laptop keys.class-user ];
  "attic-server-env.age".publicKeys = [ keys.vps keys.laptop keys.class-user ];
  "forgejo-admin-password.age".publicKeys = [ keys.vps keys.laptop keys.class-user ];
  "memos-admin-password.age".publicKeys = [ keys.vps keys.laptop keys.class-user ];
  "libretv-env.age".publicKeys = [ keys.vps keys.laptop keys.class-user ];
  "blog-preview-htpasswd.age".publicKeys = [ keys.vps keys.laptop keys.class-user ];
  "blog-cms-credentials.age".publicKeys = [ keys.vps keys.laptop keys.class-user ];
  "attic-netrc.age".publicKeys = users;
  "attic-upload-token.age".publicKeys = homeUsers;
  "dae-nodes.age".publicKeys = users;
  "hermes-env.age".publicKeys = users;
  "aria2-password.age".publicKeys = users;
  "edunet-env.age".publicKeys = users;
  "doubao-asr.age".publicKeys = users;
  "deepseek-token.age".publicKeys = users;

  "glm-token.age".publicKeys = homeUsers;
  "kimi-token.age".publicKeys = homeUsers;
  "minimax-token.age".publicKeys = homeUsers;
  "codex-cpa-token.age".publicKeys = homeUsers;
}
