{ pkgs, ... }:

{
  programs.virt-manager.enable = true;

  virtualisation = {
    libvirtd = {
      enable = true;

      qemu = {
        # Only the native architecture is needed on this x86_64 host.
        package = pkgs.qemu_kvm;
        runAsRoot = false;
        swtpm.enable = true;
        vhostUserPackages = [ pkgs.virtiofsd ];
      };
    };

    # Allow USB devices to be redirected to SPICE guests from virt-manager.
    spiceUSBRedirection.enable = true;
  };

  users.users.chumeng.extraGroups = [ "kvm" "libvirtd" ];
}
