{
  description = "A simple NixOS flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.05";
    home-manager.url = "github:nix-community/home-manager/release-25.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    daeuniverse.url = "github:daeuniverse/flake.nix";
    ragenix.url = "github:yaxitech/ragenix";
    chinese-fonts-overlay.url = "github:lihaoze123/chinese-fonts-overlay/main";
    silentSDDM = {
      url = "github:uiriansan/SilentSDDM";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ragenix, ... }@inputs: {
    nixosConfigurations.laptop = nixpkgs.lib.nixosSystem {
      specialArgs =
        let
          system = "x86_64-linux";
        in
        {
          inherit inputs;
          pkgs-stable = import inputs.nixpkgs-stable {
            inherit system;
            config.allowUnfree = true;
          };
        };
      modules = [
        ./hosts/laptop
      ];
    };

    nixosConfigurations.class = nixpkgs.lib.nixosSystem {
      specialArgs =
        let
          system = "x86_64-linux";
        in
        {
          inherit inputs;
          pkgs-stable = import inputs.nixpkgs-stable {
            inherit system;
            config.allowUnfree = true;
          };
        };
      modules = [
        ./hosts/class
      ];
    };

    nixosConfigurations.home = nixpkgs.lib.nixosSystem {
      specialArgs =
        let
          system = "x86_64-linux";
        in
        {
          inherit inputs;
          pkgs-stable = import inputs.nixpkgs-stable {
            inherit system;
            config.allowUnfree = true;
          };
        };
      modules = [
        ./hosts/home
      ];
    };

    nixosConfigurations.nixos = self.nixosConfigurations.laptop;

    formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixpkgs-fmt;
  };
}
