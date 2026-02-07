{ config, pkgs, inputs, ... }:
let
  tex = (pkgs.texlive.combine {
    inherit (pkgs.texlive) scheme-full fandol;
  });
in
{
  imports = [
    ./vscode.nix
    ./antigravity-tools.nix
  ];

  home.packages = with pkgs;[
    # browser
    inputs.browser-previews.packages.${pkgs.system}.google-chrome-dev
    inputs.browser-previews.packages.${pkgs.system}.google-chrome
    microsoft-edge

    # massage
    qq
    wechat
    feishu

    # learn
    anki
    (pkgs.symlinkJoin {
      name = "obsidian";
      paths = [ obsidian ];
      buildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/obsidian \
          --add-flags "--no-sandbox" \
          --add-flags "--ozone-platform=wayland" \
          --add-flags "--ozone-platform-hint=auto" \
          --add-flags "--enable-features=UseOzonePlatform,WaylandWindowDecorations"
      '';
    })

    # typeset
    pandoc
    # tex
    tectonic
    # typora
    wpsoffice

    # image
    inkscape

    # develop
    dbeaver-bin
    wineWowPackages.stable
    antigravity
    jetbrains.idea
  ];
}
