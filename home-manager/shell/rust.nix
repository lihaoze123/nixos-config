{ config, mkRustToolchain, pkgs, ... }:
let
  rustToolchain = mkRustToolchain pkgs;
  rustRoverToolchainDir = "${config.home.homeDirectory}/.rust-rover/toolchain";
in
{
  home.packages = with pkgs; [
    rustToolchain
    rust-analyzer
    openssl
    pkg-config
  ];

  home.file.".rust-rover/toolchain/bin".source = "${rustToolchain}/bin";
  home.file.".rust-rover/toolchain/lib".source = "${rustToolchain}/lib";

  home.sessionVariables.RUST_SRC_PATH =
    "${rustRoverToolchainDir}/lib/rustlib/src/rust/library";
}
