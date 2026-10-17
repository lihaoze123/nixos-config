{ pkgs, ... }:
{
  boot.kernelModules = [ "tcp_bbr" "sch_fq" ];
  boot.kernel.sysctl = {
    "net.ipv4.tcp_congestion_control" = "bbr";
    "net.core.default_qdisc" = "fq";
  };

  # Changing default_qdisc does not replace queues on an existing interface.
  systemd.services.vps-wan-fq = {
    description = "Configure fq on the OCI WAN transmit queues";
    wantedBy = [ "multi-user.target" ];
    requires = [ "sys-subsystem-net-devices-enp0s6.device" ];
    after = [
      "systemd-modules-load.service"
      "systemd-sysctl.service"
      "systemd-networkd.service"
      "sys-subsystem-net-devices-enp0s6.device"
    ];
    path = [ pkgs.iproute2 pkgs.jq ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      set -euo pipefail
      # Keep mq and give it a handle so each transmit queue is addressable.
      tc qdisc replace dev enp0s6 root handle 1: mq
      tc -j qdisc show dev enp0s6 |
        jq -r '.[] | select(.parent != null) | .parent' |
        while IFS= read -r parent; do
          tc qdisc replace dev enp0s6 parent "$parent" fq
        done
    '';
  };
}
