{ config, lib, ... }:
let
  cfg = config.my.hardware.bluetooth;
in
{
  options.my.hardware.bluetooth.enable = lib.mkEnableOption "Bluetooth and its desktop applet";

  config = lib.mkIf cfg.enable {
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;
      settings = {
        General = { Experimental = true; FastConnectable = true; };
        Policy.AutoEnable = true;
      };
    };
    services.blueman.enable = config.my.desktop.enable;
    users.users.${config.my.user.name}.extraGroups = [ "bluetooth" ];
  };
}
