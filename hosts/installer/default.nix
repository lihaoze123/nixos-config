{ modulesPath, pkgs, ... }:
{
  imports = [
    (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix")
  ];

  users.users.root.openssh.authorizedKeys.keys = [
    (import ../../secrets/keys.nix).laptop
  ];
  services.openssh.enable = true;

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    substituters = [ "https://mirror.tuna.tsinghua.edu.cn/nix-channels/store" ];
  };

  networking.hostName = "installer";
  networking.networkmanager.enable = true;

  environment.systemPackages = with pkgs; [ git jujutsu vim ];
}
