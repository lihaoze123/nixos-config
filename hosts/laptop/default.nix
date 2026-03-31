{ inputs, pkgs, pkgs-stable, system, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../base.nix
    inputs.ragenix.nixosModules.default
    inputs.home-manager.nixosModules.home-manager
    {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.users.chumeng = import ./laptop.nix;
      home-manager.extraSpecialArgs = { inherit inputs pkgs-stable system; };
    }
    (import ../../modules)
    (import ../../overlays)
  ];

  networking.hostName = "laptop";

  programs.steam = {
    enable = true;
  };

  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;

  virtualisation.virtualbox.host.enable = true;
  virtualisation.virtualbox.host.enableExtensionPack = true;
  networking.firewall.trustedInterfaces = [ "virbr0" ];

  users.users.chumeng.extraGroups = [ "libvirtd" "vboxusers" ];

  environment.systemPackages = with pkgs; [
    virt-manager
    qemu_kvm
    dnsmasq
    flclash
  ];
}
