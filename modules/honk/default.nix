{ config, lib, pkgs, inputs, ... }:
let
  honk = pkgs.callPackage ./package.nix { };
  runtimeConfig = pkgs.writeText "honk-config.dae"
    ((import ../dae/render-config.nix { inherit config lib; }) + builtins.readFile ./config.dae);
in
{
  config = lib.mkIf config.my.features.honk.enable {
    boot.kernelModules = [ "nfnetlink_queue" ];
    systemd.tmpfiles.rules = [ "d /run/netns 0755 root root - -" ];
    environment.systemPackages = [ honk ];
    networking.firewall.allowedTCPPorts = [ 12345 ];
    networking.firewall.allowedUDPPorts = [ 12345 ];

    systemd.services.honk = {
      description = "honk transparent proxy and local doona dashboard";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" "systemd-sysctl.service" ];
      conflicts = [ "dae.service" ];
      restartTriggers = [ runtimeConfig config.age.secrets.dae-nodes.file ];
      environment.DAE_LOCATION_ASSET = toString inputs.geodb;
      preStart = ''
        install -m 0600 ${runtimeConfig} /run/honk/config.dae
        install -m 0600 ${config.age.secrets.dae-nodes.path} /run/honk/nodes.dae
      '';
      serviceConfig = {
        Type = "notify";
        User = "root";
        ExecStart = "${lib.getExe honk} --config /run/honk/config.dae --disable-timestamp";
        ExecReload = "${lib.getExe honk} reload";
        Restart = "on-failure";
        RestartSec = "2s";
        TimeoutStopSec = "30s";
        RuntimeDirectory = "honk";
        RuntimeDirectoryMode = "0700";
        StateDirectory = "honk";
        StateDirectoryMode = "0700";
        WorkingDirectory = "/var/lib/honk";
        LimitNOFILE = 1048576;
        LimitMEMLOCK = "infinity";
        UMask = "0077";
      };
    };
  };
}
