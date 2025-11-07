{ pkgs
, lib
, config
, ...
}@inputs:
let
  claude_alt = { name, url, token_path }: (
    pkgs.writeShellScriptBin name ''
      export ANTHROPIC_AUTH_TOKEN=$(cat ${token_path})
      export ANTHROPIC_BASE_URL=${url}
      exec claude "$@"
    ''
  );
  claude_alt_models_modified = {
    name,
    url,
    token_path,
    reasoner,
    chat,
  }: (
    pkgs.writeShellScriptBin name ''
      export ANTHROPIC_AUTH_TOKEN=$(cat ${token_path})
      export ANTHROPIC_BASE_URL=${url}
      export ANTHROPIC_MODEL=${reasoner}
      export ANTHROPIC_SMALL_FAST_MODEL=${chat}

      exec claude "$@"
    ''
  );
in
{
  age.secrets.glm-token = {
    file = ../../secrets/glm-token.age;
  };
  age.secrets.kimi-token = {
    file = ../../secrets/kimi-token.age;
  };
  age.secrets.minimax-token = {
    file = ../../secrets/minimax-token.age;
  };

  home.packages = with pkgs; [
    claude-code

    (claude_alt {
      name = "glm";
      url = "https://open.bigmodel.cn/api/anthropic";
      token_path = config.age.secrets.glm-token.path;
    })
    (claude_alt_models_modified {
      name = "kimi";
      url = "https://api.kimi.com/coding/";
      token_path = config.age.secrets.kimi-token.path;
      reasoner = "kimi-k2-thinking";
      chat = "kimi-k2-thinking";
    })
    (claude_alt {
      name = "minimax";
      url = "https://api.minimax.io/anthropic";
      token_path = config.age.secrets.minimax-token.path;
    })
  ];
}
