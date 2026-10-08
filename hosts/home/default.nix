{ inputs, pkgs-stable, system, config, lib, ... }:
let
  # GPU containers need the NVIDIA driver even without a graphical session.
  useNvidia = config.my.features.desktop.enable || config.my.features.docker.enable;
in
{
  imports = [
    ./features.nix
    ./hardware-configuration.nix
    ../base.nix
    inputs.ragenix.nixosModules.default
    inputs.home-manager.nixosModules.home-manager
    {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.users.chumeng = import ./home.nix;
      home-manager.extraSpecialArgs = { inherit inputs pkgs-stable system; };
    }
    (import ../../modules)
    (import ../../overlays)
  ];

  networking.hostName = "home";

  # Dank Greeter output, matching config-home.kdl.
  my.niri.greeterExtraConfig = ''
    output "DP-1" {
        mode "3440x1440@144.0"
        scale 1.2
    }
  '';

  # Hardware configuration for home host
  hardware.graphics = {
    enable = useNvidia;
  };

  services.xserver.videoDrivers = lib.mkIf useNvidia [ "nvidia" ];

  hardware.nvidia = lib.mkIf useNvidia {
    modesetting.enable = true;
    powerManagement.enable = false;
    powerManagement.finegrained = false;
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  hardware.nvidia-container-toolkit.enable = config.my.features.docker.enable;

  # Printer configuration
  users.users.chumeng.extraGroups = lib.optional config.my.features.printing.enable "lpadmin";

  services.printing = lib.mkIf config.my.features.printing.enable {
    enable = true;
    drivers = with pkgs-stable; [ hplipWithPlugin ];
  };

  services.avahi = lib.mkIf config.my.features.printing.enable {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  # Docker with NVIDIA support
  virtualisation.docker.extraPackages = lib.mkIf config.my.features.docker.enable [ pkgs-stable.nvidia-container-toolkit ];

  # Syncthing configuration
  services.syncthing = lib.mkIf config.my.features.syncthing.enable {
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

  systemd.tmpfiles.rules = lib.mkIf config.my.features.syncthing.enable [
    "d /home/chumeng/Documents/.obsidian/Notes/Tweets 0755 chumeng syncthing -"
  ];
}
