{ config, pkgs, lib, inputs, ... }:
let
  sddm-theme = inputs.silentSDDM.packages.${pkgs.system}.default.override {
    theme = "default";
    theme-overrides = {
      "General" = {
        scale = 2.0;
      };
    };
  };
in
{
  qt.enable = true;
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    package = pkgs.kdePackages.sddm;
    theme = sddm-theme.pname;
    extraPackages = sddm-theme.propagatedBuildInputs;
    settings = {
      General = {
        GreeterEnvironment = "QML2_IMPORT_PATH=${sddm-theme}/share/sddm/themes/${sddm-theme.pname}/components/,QT_IM_MODULE=qtvirtualkeyboard";
        InputMethod = "qtvirtualkeyboard";
      };
    };
  };

  systemd.services."sddm-avatar" = {
    description = "Service to copy or update users Avatars at startup.";
    wantedBy = [ "multi-user.target" ];
    before = [ "sddm.service" ];
    script = ''
      mkdir -p /var/lib/AccountsService/icons

      for user in /home/*; do

        username=$(basename "$user")
        icon_source="$user/.face.icon"
        icon_dest="/var/lib/AccountsService/icons/$username"

        if [ -f "$icon_source" ]; then
          if [ ! -f "$icon_dest" ] || ! cmp -s "$icon_source" "$icon_dest"; then
            rm -f "$icon_dest"
            cp -L "$icon_source" "$icon_dest"
          fi
        fi

      done
    '';
    serviceConfig = {
      Type = "simple";
      User = "root";
      StandardOutput = "journal+console";
      StandardError = "journal+console";
    };
  };

  systemd.services.sddm = {
    after = [ "sddm-avatar.service" ];
  };

  environment.systemPackages = with pkgs; [
    sddm-theme
  ];
}
