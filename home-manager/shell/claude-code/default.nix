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
in
{
  age.secrets.glm-token = {
    file = ../../secrets/glm-token.age;
  };
  age.secrets.kimi-token = {
    file = ../../secrets/kimi-token.age;
  };

  home.packages = with pkgs; [
    claude-code

    (claude_alt {
      name = "glm";
      url = "https://open.bigmodel.cn/api/anthropic";
      token_path = config.age.secrets.glm-token.path;
    })
    (claude_alt {
      name = "kimi";
      url = "https://api.moonshot.cn/anthropic";
      token_path = config.age.secrets.kimi-token.path;
    })
  ];
}
