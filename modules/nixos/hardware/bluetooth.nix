{ config, lib, ... }:
let
  cfg = config.my;
in
lib.mkIf cfg.hardware.bluetooth.enable {
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = { Experimental = true; FastConnectable = true; };
      Policy.AutoEnable = true;
    };
  };
  services.blueman.enable = cfg.desktop.enable;
  users.users.${config.my.user.name}.extraGroups = [ "bluetooth" ];
}
