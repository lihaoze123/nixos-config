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
    (pkgs.symlinkJoin {
      name = "google-chrome-dev";
      paths = [ inputs.browser-previews.packages.${pkgs.system}.google-chrome-dev ];
      buildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/google-chrome-unstable \
          --add-flags "--disable-gpu" \
          --add-flags "--disable-gpu-compositing" \
          --add-flags "--disable-features=UseChromeOSDirectVideoDecoder" \
          --add-flags "--ignore-gpu-blocklist"
      '';
    })
    (pkgs.symlinkJoin {
      name = "microsoft-edge";
      paths = [ microsoft-edge ];
      buildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/microsoft-edge \
          --add-flags "--disable-gpu" \
          --add-flags "--disable-gpu-compositing" \
          --add-flags "--disable-features=UseChromeOSDirectVideoDecoder" \
          --add-flags "--ignore-gpu-blocklist"
      '';
    })

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
          --add-flags "--enable-features=UseOzonePlatform,WaylandWindowDecorations" \
          --add-flags "--disable-gpu"
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
