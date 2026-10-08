{ pkgs, inputs, system }:
# Export individual packages without attaching them to the NixOS closure.
# Install only what is needed: nix profile install .#anki
{
  inherit (pkgs)
    microsoft-edge qq wechat anki obsidian pandoc typst tectonic
    pavucontrol gnome-disk-utility baobab neovide ghostty
    fastfetch lazygit zellij tealdeer;
  try = inputs.try.packages.${system}.default.overrideAttrs (old: {
    nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.ruby_3_3 ];
    postFixup = (old.postFixup or "") + ''
      patchShebangs "$out/bin/.try-wrapped"
    '';
  });
  filelight = pkgs.kdePackages.filelight;
  vscode = pkgs.vscode-with-extensions.override {
    vscodeExtensions = with pkgs.vscode-extensions; [
      dracula-theme.theme-dracula
      vscodevim.vim
      myriad-dreamin.tinymist
      ms-ceintl.vscode-language-pack-zh-hans
      adpyke.codesnap
      james-yu.latex-workshop
    ];
  };
}
