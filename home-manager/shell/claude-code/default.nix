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
  claude_alt_models_modified =
    { name
    , url
    , token_path
    , reasoner
    , chat
    ,
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
  age.secrets.codex-cpa-token = {
    file = ../../secrets/codex-cpa-token.age;
  };

  home.packages = with pkgs; [
    claude-code

    (claude_alt_models_modified {
      name = "glm";
      url = "https://open.bigmodel.cn/api/anthropic";
      token_path = config.age.secrets.glm-token.path;
      reasoner = "glm-5.1";
      chat = "glm-5.1";
    })
    (claude_alt_models_modified {
      name = "kimi";
      url = "https://api.kimi.com/coding/";
      token_path = config.age.secrets.kimi-token.path;
      reasoner = "kimi-k2-thinking";
      chat = "kimi-k2-thinking";
    })
    (claude_alt_models_modified {
      name = "minimax";
      url = "https://api.minimaxi.com/anthropic";
      token_path = config.age.secrets.minimax-token.path;
      reasoner = "MiniMax-M2.7-highspeed";
      chat = "MiniMax-M2.7-highspeed";
    })
    (claude_alt_models_modified {
      name = "codexcc";
      url = "localhost:8317";
      token_path = config.age.secrets.codex-cpa-token.path;
      reasoner = "gpt-5.4";
      chat = "gpt-5.4";
    })
  ];
}
