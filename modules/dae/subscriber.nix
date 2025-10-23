{ config, lib, pkgs, inputs, ... }:
{
  age.secrets.dae-sub = {
    file = ../../secrets/dae-sub.age;
    path = "/etc/dae/sublist";
    symlink = false;
  };

  systemd.timers."update-subs" = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5m";
      OnUnitActiveSec = "12h";
      Unit = "update-subs.service";
    };
  };

  systemd.services."update-subs" = {
    script = ''
      #!/usr/bin/env nix-shell
      cd /etc/dae || exit 1
      version="$(${inputs.daeuniverse.packages.x86_64-linux.dae}/bin/dae --version | head -n 1 | sed 's/dae version //')"
      UA="dae/$version (like v2rayA/1.0 WebRequestHelper) (like v2rayN/1.0 WebRequestHelper)"
      fail=false
      updated=false

      while IFS=':' read -r name url
      do
              ${pkgs.curl}/bin/curl --retry 3 --retry-delay 5 -fL -A "$UA" "$url" -o "$name.sub.new"
              if [[ $? -eq 0 ]]; then
                      mv "$name.sub.new" "$name.sub"
                      chmod 0600 "$name.sub"
                      echo "Downloaded $name"
                      updated=true
              else
                      if [ -f "$name.sub.new" ]; then
                              rm "$name.sub.new"
                      fi
                      fail=true
                      echo "Failed to download $name"
              fi
      done < sublist

      if $fail; then
              echo "Failed to update some subs"
              if [ "$updated" = true ]; then
                      echo "Some subs were updated, restarting dae service"
                      systemctl restart dae.service
              fi
              exit 2
      fi

      if [ "$updated" = true ]; then
              echo "All subs updated successfully, restarting dae service"
              systemctl restart dae.service
      else
              echo "No subs needed updating"
      fi
    '';

    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };
  };
}
