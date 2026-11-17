{ lib, pkgs, osConfig, ... }:
let
  valent = pkgs.valent.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./valent-wl-clipboard.patch ];
    postPatch = (old.postPatch or "") + ''
      substituteInPlace src/plugins/gtk/valent-gdk-clipboard.c \
        --replace-fail '@wlPaste@' '${pkgs.wl-clipboard}/bin/wl-paste' \
        --replace-fail '@wlCopy@' '${pkgs.wl-clipboard}/bin/wl-copy'
    '';
  });
in
lib.mkIf osConfig.my.desktop.phone.enable {
  # Mutter's adapter has higher priority, but its service is absent in Niri.
  dconf.settings."ca/andyholmes/valent/clipboard/plugin/gnome".enabled = false;

  systemd.user.services.valent = {
    Unit = {
      Description = "Phone connectivity for DMS";
      After = [ "graphical-session.target" "gcr-ssh-agent.socket" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${valent}/bin/valent --gapplication-service";
      Environment = [
        "SSH_AUTH_SOCK=%t/gcr/ssh"
        # Valent needs the GVfs backend to mount the phone's SFTP share.
        "GIO_EXTRA_MODULES=${pkgs.gvfs}/lib/gio/modules"
        # Use Niri's data-control protocol for background clipboard access.
        "VALENT_WL_CLIPBOARD=1"
      ];
      Restart = "on-failure";
      RestartSec = 3;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
