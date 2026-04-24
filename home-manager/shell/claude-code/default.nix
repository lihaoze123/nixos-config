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
    , opus
    , sonnet
    , haiku
    ,
    }: (
      pkgs.writeShellScriptBin name ''
        export ANTHROPIC_AUTH_TOKEN=$(cat ${token_path})
        export ANTHROPIC_BASE_URL=${url}
        export ANTHROPIC_MODEL=${opus}
        export ANTHROPIC_DEFAULT_OPUS_MODEL=${opus}
        export ANTHROPIC_DEFAULT_SONNET_MODEL=${sonnet}
        export ANTHROPIC_DEFAULT_HAIKU_MODEL=${haiku}

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
      opus = "glm-5.1";
      sonnet = "glm-5.1";
      haiku = "glm-4.7";
    })
    (claude_alt_models_modified {
      name = "codexcc";
      url = "localhost:8317";
      token_path = config.age.secrets.codex-cpa-token.path;
      opus = "gpt-5.5";
      sonnet = "gpt-5.5";
      haiku = "gpt-5.5";
    })
  ];
}
