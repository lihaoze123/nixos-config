{ config, pkgs, pkgs-stable, system, inputs, ... }:
let
  # try init invokes the inner script directly, bypassing the PATH wrapper.
  tryPackage = inputs.try.packages.${system}.default.overrideAttrs (old: {
    nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.ruby_3_3 ];
    postFixup = (old.postFixup or "") + ''
      patchShebangs "$out/bin/.try-wrapped"
    '';
  });
in
{
  imports = [
    ./fcitx5
    ./shell
    ./niri
    ./applications
    inputs.ragenix.homeManagerModules.default
    inputs.try.homeModules.default
  ];
  programs.try = {
    enable = true;
    package = tryPackage;
  };
  home.enableNixpkgsReleaseCheck = false;
  age.identityPaths = [ "/home/chumeng/.ssh/id_rsa" ];

  home.username = "chumeng";
  home.homeDirectory = "/home/chumeng";

  home.packages = with pkgs;[
    tryPackage

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
  ];

  programs.git = {
    enable = true;
    settings.user = {
      name = "chumeng";
      email = "2595248810@qq.com";
    };
  };

  home.stateVersion = "25.05";
}
