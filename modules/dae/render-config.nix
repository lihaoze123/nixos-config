{ config, lib }:
let
  lanInterfaces = lib.optional config.virtualisation.docker.enable "docker0"
    ++ lib.optional config.virtualisation.libvirtd.enable "virbr0";
  lanConfig = lib.optionalString (lanInterfaces != [ ])
    "    lan_interface: ${lib.concatStringsSep "," lanInterfaces}\n";
in
lib.replaceStrings
  [ "global {\n" ]
  [ ("global {\n" + lanConfig) ]
  (builtins.readFile ./config.dae)
