{
  description = "Project-local development environments; keep only the shells this project uses";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  outputs = { nixpkgs, ... }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
    in
    {
      devShells = nixpkgs.lib.genAttrs systems (system:
        let pkgs = import nixpkgs { inherit system; };
        in {
          rust = pkgs.mkShell {
            packages = with pkgs; [ rustc cargo rustfmt clippy rust-analyzer pkg-config ];
            buildInputs = [ pkgs.openssl ];
            RUST_SRC_PATH = "${pkgs.rustPlatform.rustLibSrc}";
          };
          cpp = pkgs.mkShell {
            packages = with pkgs; [ gcc clang-tools cmake ninja pkg-config ];
          };
          node = pkgs.mkShell {
            packages = with pkgs; [ nodejs bun ];
          };
          python = pkgs.mkShell {
            packages = with pkgs; [ python3 uv ];
          };
          java = pkgs.mkShell {
            packages = with pkgs; [ jdk maven ];
          };
        });
    };
}
