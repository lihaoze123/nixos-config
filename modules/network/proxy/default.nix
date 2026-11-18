{ config, lib, ... }:
let
  inherit (lib) mkOption types;
  cfg = config.my.network.proxy;
  unitNames = map (s: "${s}.service") cfg.afterServices;
in
{
  imports = [ ./dae ./honk ];

  options.my.network.proxy = {
    backend = mkOption {
      type = types.nullOr (types.enum [ "dae" "honk" ]);
      default = null;
      description = "Transparent proxy using the shared encrypted nodes; null disables it.";
    };
    lanInterfaces = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "virbr0" ];
      description = ''
        LAN interfaces whose forwarded traffic dae or honk should proxy.
        These interfaces must exist before the proxy starts. The libvirt
        module adds virbr0 and starts its default network before the proxy.
        Docker bridges must be added explicitly.
      '';
    };
    afterServices = mkOption {
      internal = true;
      type = types.listOf types.str;
      default = [ ];
      example = [ "libvirt-default-network" ];
      description = "Systemd service names (without .service suffix) that must start before the transparent proxy.";
    };
  };

  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = !(cfg.backend == "honk" && config.services.dae.enable);
          message = "my.network.proxy.backend = \"honk\" conflicts with services.dae";
        }
      ];
    }
    (lib.mkIf (cfg.afterServices != [ ]) {
      systemd.services = lib.genAttrs cfg.afterServices (_: {
        before = [ "dae.service" "honk.service" ];
      });
    })
    (lib.mkIf (cfg.backend == "dae" && cfg.afterServices != [ ]) {
      systemd.services.dae = {
        requires = unitNames;
        after = unitNames;
      };
    })
    (lib.mkIf (cfg.backend == "honk" && cfg.afterServices != [ ]) {
      systemd.services.honk = {
        requires = unitNames;
        after = unitNames;
      };
    })
  ];
}
