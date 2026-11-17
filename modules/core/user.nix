{ config, lib, pkgs, inputs, system, myLib, ... }:
let
  inherit (lib) mkOption types;
  user = config.my.user;
in
{
  imports = [
    inputs.ragenix.nixosModules.default
    inputs.home-manager.nixosModules.home-manager
  ];

  options.my = {
    user = {
      name = mkOption {
        type = types.str;
        default = "chumeng";
        description = "The single desktop user managed by this configuration.";
      };
      home = mkOption {
        type = types.str;
        default = "/home/${user.name}";
        defaultText = lib.literalExpression "\"/home/\${config.my.user.name}\"";
        description = "Home directory of my.user.name.";
      };
      ageIdentity = mkOption {
        type = types.str;
        default = "${user.home}/.ssh/id_rsa";
        defaultText = lib.literalExpression "\"\${config.my.user.home}/.ssh/id_rsa\"";
        description = "Default SSH key path used for ragenix decryption.";
      };
    };

    configPath = mkOption {
      type = types.nullOr types.str;
      default = "${user.home}/nixos-config";
      defaultText = lib.literalExpression "\"\${config.my.user.home}/nixos-config\"";
      description = ''
        Checkout of this repository. Neovim and niri configs link into it so that
        edits apply without a rebuild; null ships read-only copies from the store.
      '';
    };

    home = mkOption {
      type = types.deferredModule;
      default = { };
      description = "Home Manager module definitions for my.user.name.";
    };
  };

  config = {
    users.users.${user.name} = {
      isNormalUser = true;
      description = user.name;
      extraGroups = [ "wheel" ] ++ lib.optional config.networking.networkmanager.enable "networkmanager";
    };

    age.identityPaths = lib.mkDefault [ user.ageIdentity ];

    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      # Applications can replace managed symlinks with regular files. Keep every
      # displaced version without letting an existing .backup block activation.
      backupCommand = lib.mkDefault (pkgs.writeShellScript "home-manager-backup" ''
        set -eu
        exec ${pkgs.coreutils}/bin/mv --backup=numbered --no-target-directory -- "$1" "$1.backup"
      '');
      users.${user.name}.imports = [ config.my.home ];
      extraSpecialArgs = { inherit inputs system myLib; };
    };

    my.home = lib.setDefaultModuleLocation ./user.nix {
      imports = [ inputs.ragenix.homeManagerModules.default ];
      home.enableNixpkgsReleaseCheck = false;
      age.identityPaths = lib.mkDefault [ user.ageIdentity ];
      home.username = user.name;
      home.homeDirectory = user.home;
      home.packages = with pkgs; [
        # archives
        zip
        xz
        unzip
        p7zip

        # secret
        inputs.ragenix.packages.${system}.default

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
      home.stateVersion = "25.05";
    };
  };
}
