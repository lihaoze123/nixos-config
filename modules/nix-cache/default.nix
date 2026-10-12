{ config, ... }:
{
  age.secrets.r2-cache-credentials = {
    file = ../../secrets/r2-cache-credentials.age;
    mode = "0400";
  };

  systemd.services.nix-daemon = {
    environment.AWS_SHARED_CREDENTIALS_FILE =
      config.age.secrets.r2-cache-credentials.path;
    restartTriggers = [ config.age.secrets.r2-cache-credentials.file ];
  };

  nix.settings = {
    extra-substituters = [
      "https://fcitx5-vinput.cachix.org"
      "https://niri-computer-use.cachix.org"
      "https://codex-desktop-linux.cachix.org"
      "s3://nix-cache?endpoint=6ed1b3dcdc0ddb8c496ad7de884c55cc.r2.cloudflarestorage.com&region=auto&profile=r2-cache"
    ];
    extra-trusted-public-keys = [
      "fcitx5-vinput.cachix.org-1:XpX3AA6+dDIX4qJhb1QM7sbTwX6/qSlGvW8Z5NK6XdU="
      "niri-computer-use.cachix.org-1:K5LGfljid+PkRn02OLbwsmngqBCoLkbDi9hRMCnsOTg="
      "codex-desktop-linux.cachix.org-1:nX/xy6AdK9hQE24A8ALGjkCKj2ObFmcnemiL5Cid4nk="
      "r2-fonts-1:WlP+O4M04sA1u8qsLINKBmzg2YUHWJGQQRi3dbqDJaA="
    ];
  };
}
