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
      "s3://nix-cache?endpoint=6ed1b3dcdc0ddb8c496ad7de884c55cc.r2.cloudflarestorage.com&region=auto&profile=r2-cache"
    ];
    extra-trusted-public-keys = [
      "r2-fonts-1:WlP+O4M04sA1u8qsLINKBmzg2YUHWJGQQRi3dbqDJaA="
    ];
  };
}
