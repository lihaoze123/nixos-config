{ config, lib, pkgs, system, inputs, osConfig, ... }:
{
  imports = [
    ./shell
    ./desktop
    ./ai
    ./apps.nix
    inputs.ragenix.homeManagerModules.default
  ];
  programs.dank-material-shell.enable = osConfig.my.desktop.enable;
  programs.vocotype.doubao.enable = osConfig.my.input.speech.doubao.enable;
  home.enableNixpkgsReleaseCheck = false;
  age.identityPaths = lib.mkDefault [ "${osConfig.my.user.home}/.ssh/id_rsa" ];

  home.username = osConfig.my.user.name;
  home.homeDirectory = osConfig.my.user.home;
  age.secrets.attic-upload-token = lib.mkIf (osConfig.my.nix.cacheProfile == "private") {
    file = ../../secrets/attic-upload-token.age;
    path = "${config.xdg.dataHome}/attic/token";
  };
  xdg.configFile."attic/config.toml" = lib.mkIf (osConfig.my.nix.cacheProfile == "private") {
    text = ''
      default-server = "personal"

      [servers.personal]
      endpoint = "https://cache.chumeng.xyz/"
      token-file = "${config.age.secrets.attic-upload-token.path}"
    '';
  };

  home.packages = with pkgs;[
    # archives
    zip
    xz
    unzip
    p7zip

    # secret
    inputs.ragenix.packages."${system}".default

    # misc
    file
    which
    tree
    gnused
    gnutar
    gawk
    zstd
    gnupg

    # nix related
    nix-output-monitor
  ] ++ lib.optionals (osConfig.my.nix.cacheProfile == "private") [ pkgs.attic-client ];

  home.stateVersion = "25.05";
}
