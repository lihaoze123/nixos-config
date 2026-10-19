{ lib, pkgs, osConfig, ... }:
lib.mkIf osConfig.my.cli.extra.enable {
  programs.helix = {
    enable = true;
    defaultEditor = true;
    # Rust and C/C++ tools come from the project's devShell.
    extraPackages = with pkgs; [ nil nixpkgs-fmt ];

    settings = {
      theme = "dracula";
      keys = {
        insert."C-[" = "normal_mode";
        select."C-[" = "normal_mode";
      };
      editor = {
        line-number = "relative";
        cursorline = true;
        bufferline = "multiple";
        cursor-shape = {
          normal = "block";
          insert = "bar";
          select = "underline";
        };
      };
    };

    languages.language = [
      {
        name = "rust";
        language-servers = [ "rust-analyzer" ];
        auto-format = true;
      }
      {
        name = "c";
        language-servers = [ "clangd" ];
        auto-format = true;
      }
      {
        name = "cpp";
        language-servers = [ "clangd" ];
        auto-format = true;
      }
      {
        name = "nix";
        language-servers = [ "nil" ];
        formatter.command = "nixpkgs-fmt";
        auto-format = true;
      }
    ];
  };
}
