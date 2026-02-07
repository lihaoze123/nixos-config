{ inputs, pkgs-stable, system, config, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../base.nix
    inputs.ragenix.nixosModules.default
    inputs.home-manager.nixosModules.home-manager
    {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.users.chumeng = import ./home.nix;
      home-manager.extraSpecialArgs = { inherit inputs pkgs-stable system; };
      nixpkgs.overlays = [ inputs.claude-code.overlays.default ];
    }
    (import ../../modules)
    (import ../../overlays)
  ];

  # Hardware configuration for home host
  hardware.graphics = {
    enable = true;
  };

  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;
    powerManagement.finegrained = false;
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  hardware.nvidia-container-toolkit.enable = true;

  # Printer configuration
  users.users.chumeng.extraGroups = [ "lpadmin" ];

  services.printing = {
    enable = true;
    drivers = with pkgs-stable; [ hplipWithPlugin ];
  };

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  # Docker with NVIDIA support
  virtualisation.docker.extraPackages = [ pkgs-stable.nvidia-container-toolkit ];

  # Syncthing configuration
  services.syncthing = {
    enable = true;
    user = "chumeng";
    dataDir = "/home/chumeng/Documents";
    configDir = "/home/chumeng/.config/syncthing";
    settings = {
      devices = {
        "remote" = {
          id = "OD5XNWZ-FW3WZDK-JK3K7WW-EEJADOA-WLND3WI-OWN6NAN-KV22IEH-UBQXKAP";
        };
      };
      folders = {
        "Tweets" = {
          path = "/home/chumeng/Documents/.obsidian/Notes/Tweets";
          devices = [ "remote" ];
        };
      };
    };
  };

  systemd.tmpfiles.rules = [
    "d /home/chumeng/Documents/.obsidian/Notes/Tweets 0755 chumeng syncthing -"
  ];
}
