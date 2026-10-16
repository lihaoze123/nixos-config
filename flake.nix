{
  description = "A simple NixOS flake";

  inputs = {
    nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.zst";
    # Keep upstream's nixpkgs pin so the CachyOS binary cache matches.
    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/release";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nur-packages = {
      url = "github:lihaoze123/nur-packages";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    vtype-linux = {
      url = "github:zhl-HFUT/vtype-linux";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Lite contains cloud ASR only; retain upstream's nixpkgs for cache compatibility.
    fcitx5-vinput.url = "github:xifan2333/fcitx5-vinput/c46f0078de80e493f6ea3040e05c9e3308b76751";
    # Keep VoCoType's validated ONNX Runtime / FunASR dependency versions.
    vocotype.url = "github:LeonardNJU/VocoType-linux/v5.0.1";
    dms = {
      url = "github:AvengeMedia/DankMaterialShell/v1.6.2";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    daeuniverse.url = "github:daeuniverse/flake.nix";
    geodb = {
      url = "github:Loyalsoldier/v2ray-rules-dat/release";
      flake = false;
    };
    ragenix.url = "github:yaxitech/ragenix";
    chinese-fonts-overlay.url = "github:brsvh/chinese-fonts-overlay/main";
    browser-previews = {
      url = "github:nix-community/browser-previews";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    xwayland-satellite = {
      url = "github:Supreeeme/xwayland-satellite";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.rust-overlay.follows = "rust-overlay";
    };
    claude-code.url = "github:sadjow/claude-code-nix";
    codex-code.url = "github:sadjow/codex-cli-nix";
  };

  outputs = { self, nixpkgs, ... }@inputs:
    let
      inherit (import ./lib { inherit inputs; }) system mkHost;
    in
    {
      nixosConfigurations.laptop = mkHost "laptop";
      nixosConfigurations.class = mkHost "class";
      nixosConfigurations.home = mkHost "home";
      nixosConfigurations.nixos = self.nixosConfigurations.laptop;
      # Minimal system for new machines; optional features stay off.
      nixosConfigurations.base = mkHost "base";
      nixosConfigurations.vps = mkHost {
        name = "vps";
        system = "aarch64-linux";
      };
      # Live installer stays independent of the installed hosts' shared modules.
      nixosConfigurations.installer = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [ ./hosts/installer ];
      };

      packages.${system}.installer-iso = self.nixosConfigurations.installer.config.system.build.isoImage;
      apps.${system} = {
        deploy = inputs.deploy-rs.apps.${system}.default;
      };
      deploy.nodes.vps = {
        # Logical node name; pass the actual address with --hostname when deploying.
        hostname = "vps";
        sshUser = "chumeng";
        remoteBuild = true;
        autoRollback = true;
        magicRollback = true;
        profiles.system = {
          user = "root";
          path = inputs.deploy-rs.lib.aarch64-linux.activate.nixos self.nixosConfigurations.vps;
        };
      };
      templates.project = {
        path = ./templates/project/devshell;
        description = "Independent project devShells for Rust, C++, Node.js, Python and Java";
      };
      templates.java-webapp = {
        path = ./templates/project/java-webapp;
        description = "Minimal Java 8 + embedded Tomcat 9 + javax Servlet/JSP executable JAR";
      };

      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixpkgs-fmt;
    };
}
