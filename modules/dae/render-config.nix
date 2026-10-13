{ config, lib }:
let
  # Service enablement does not guarantee that a bridge exists at proxy startup.
  lanInterfaces = config.my.proxy.lanInterfaces;
  lanConfig = lib.optionalString (lanInterfaces != [ ])
    "    lan_interface: ${lib.concatStringsSep "," lanInterfaces}\n";
in
lib.replaceStrings
  [ "global {\n" ]
  [ ("global {\n" + lanConfig) ]
  (builtins.readFile ./config.dae)
