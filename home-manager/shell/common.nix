{ lib, pkgs, osConfig, inputs, system, ... }:
{
  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    enableJujutsuIntegration = true;
  };

  programs.jujutsu = {
    enable = true;
    settings = {
      user = {
        name = "chumeng";
        email = "2595248810@qq.com";
      };
      ui = {
        default-command = "log";
      };
      merge-tools.difft.diff-invocation-mode = "file-by-file";
    };
  };

  home.packages = with pkgs; [
    yazi
    fd
    fzf
    ripgrep
    eza
    bat
    gh
    jq
    just
    difftastic
    tmux
  ] ++ lib.optionals osConfig.my.features.extra.enable [
    lazygit
    zellij
    tealdeer
    fastfetch
    # Shares the NixOS shebang fix with the nix profile output.
    inputs.self.packages.${system}.try
  ] ++ lib.optionals osConfig.my.features.desktop.enable [
    satty
    grim
    slurp
  ];
}
