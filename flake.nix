{
  description = "A simple NixOS flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.05";
    home-manager.url = "github:nix-community/home-manager/release-25.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    daeuniverse.url = "github:daeuniverse/flake.nix";
    geodb = {
      url = "github:Loyalsoldier/v2ray-rules-dat/release";
      flake = false;
    };
    ragenix.url = "github:yaxitech/ragenix";
    chinese-fonts-overlay.url = "github:lihaoze123/chinese-fonts-overlay/main";
    silentSDDM = {
      url = "github:uiriansan/SilentSDDM";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    browser-previews = {
      url = "github:nix-community/browser-previews";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    claude-code.url = "github:sadjow/claude-code-nix";
    codex-code.url = "github:sadjow/codex-cli-nix";
  };

  outputs = { self, nixpkgs, home-manager, ragenix, geodb, ... }@inputs:
    let
      system = "x86_64-linux";
      mkRustToolchain = pkgs:
        pkgs.rust-bin.stable."1.88.0".default.override {
          extensions = [ "rust-src" "clippy" "rustfmt" ];
        };
      rustPkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [ inputs.rust-overlay.overlays.default ];
      };
      rustToolchain = mkRustToolchain rustPkgs;
      mkHost = hostModule: nixpkgs.lib.nixosSystem {
        specialArgs = {
          inherit inputs system mkRustToolchain;
          pkgs-stable = import inputs.nixpkgs-stable {
            inherit system;
            config.allowUnfree = true;
          };
        };
        modules = [ hostModule ];
      };
    in
    {
      nixosConfigurations.laptop = mkHost ./hosts/laptop;
      nixosConfigurations.class = mkHost ./hosts/class;
      nixosConfigurations.home = mkHost ./hosts/home;
      nixosConfigurations.nixos = self.nixosConfigurations.laptop;

      devShells.${system}.rust-rover = rustPkgs.mkShell {
        nativeBuildInputs = [
          rustToolchain
        ];

        buildInputs = with rustPkgs; [
          openssl
          pkg-config
          rust-analyzer
          jetbrains.rust-rover
        ];

        shellHook = ''
          mkdir -p ~/.rust-rover/toolchain

          ln -sfn ${rustToolchain}/lib ~/.rust-rover/toolchain
          ln -sfn ${rustToolchain}/bin ~/.rust-rover/toolchain

          export RUST_SRC_PATH="$HOME/.rust-rover/toolchain/lib/rustlib/src/rust/library"
        '';
      };

      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixpkgs-fmt;
    };
}
