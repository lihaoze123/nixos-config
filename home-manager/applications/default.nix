{ config, pkgs, inputs, ... }:
let
  tex = (pkgs.texlive.combine {
    inherit (pkgs.texlive) scheme-full fandol;
  });
  codexDmg = pkgs.fetchurl {
    url = "https://persistent.oaistatic.com/codex-app-prod/Codex.dmg";
    hash = "sha256-WTeptN8D9hF2ffvlJKppfLTOJr5Z0hjokHCnGX6drk0=";
  };
  codexDesktop = inputs.codex-desktop.packages.${pkgs.system}.codex-desktop.overrideAttrs (old: {
    src = old.src.overrideAttrs (payloadOld:
      let
        oldInstallPhase = builtins.unsafeDiscardStringContext payloadOld.installPhase;
        oldCodexDmg = builtins.unsafeDiscardStringContext (builtins.head (
          builtins.match ".*(/nix/store/[^[:space:]]+-Codex[.]dmg).*" payloadOld.installPhase
        ));
      in
      {
        nativeBuildInputs = payloadOld.nativeBuildInputs ++ [ pkgs._7zz pkgs.cacert ];
        postPatch = (payloadOld.postPatch or "") + ''
          substituteInPlace scripts/lib/dmg.sh \
            --replace-fail 'ELECTRON_VERSION="$detected_version"' 'if [[ "$detected_version" == 42.* ]]; then warn "Using fallback Electron v$ELECTRON_VERSION instead of detected v$detected_version"; else ELECTRON_VERSION="$detected_version"; fi'
        '';
        installPhase = builtins.replaceStrings [ oldCodexDmg ] [ "${codexDmg}" ] oldInstallPhase;
        outputHash = "sha256-bEb9qeTdkYdIk/8pJXmP2fe3TDG4rSWc3pESh4VuGzs=";
      });
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
    inputs.browser-previews.packages.${pkgs.system}.google-chrome-beta

    # tools
    pavucontrol
    moonlight-qt

    # massage
    qq
    wechat
    feishu

    # media
    spotify

    # learn
    anki
    obsidian
    inputs.inkline.packages.${pkgs.system}.default

    # typeset
    pandoc
    typst
    # tex
    tectonic
    # typora
    wpsoffice

    # image
    inkscape

    # develop
    tmux
    dbeaver-bin
    antigravity
    codexDesktop
    jetbrains.idea
    cherry-studio
    rtk
  ];
}
