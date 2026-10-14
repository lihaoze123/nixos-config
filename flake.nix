{
  description = "A simple NixOS flake";

  inputs = {
    nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.zst";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.05";
    # Keep upstream's nixpkgs pin so the CachyOS binary cache matches.
    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/release";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    disko = {
      url = "github:nix-community/disko";
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
      # Live installer stays independent of the installed hosts' shared modules.
      nixosConfigurations.installer = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [ ./hosts/installer ];
      };

      packages.${system} = inputs.nur-packages.packages.${system} // {
        # Compatibility for the existing profile entry installed from .#delta.
        delta = (import nixpkgs { inherit system; }).delta;
        installer-iso = self.nixosConfigurations.installer.config.system.build.isoImage;
      };
      # Standard applications resolve from nixpkgs without a maintained alias list.
      legacyPackages.${system} = (import nixpkgs { inherit system; config.allowUnfree = true; })
        // inputs.nur-packages.packages.${system};
      apps.${system}.with-caches = inputs.nur-packages.apps.${system}.with-caches;
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
