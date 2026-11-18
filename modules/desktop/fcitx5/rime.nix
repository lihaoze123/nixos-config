{ config, lib, pkgs, osConfig, ... }:
let
  inherit (import ./packages.nix { inherit pkgs lib; inherit (config.home) homeDirectory; })
    fcitx5-rime-crane rime-crane-config-id rime-user-data-dir
    rime-user-dictionaries rime-user-dictionary-dir rime-user-dictionary-repo;
in
lib.mkIf osConfig.my.desktop.enable {
  # Rime first, as the primary engine.
  i18n.inputMethod.fcitx5.addons = lib.mkBefore [ fcitx5-rime-crane ];

  home.file = {
    ".local/share/fcitx5/rime/default.custom.yaml".source = ./config/default.custom.yaml;
    ".local/share/fcitx5/rime/xhup.custom.yaml".source = ./config/xhup.custom.yaml;

    # Files in the Nix store have a fixed mtime, so Rime cannot notice that
    # their contents changed. Invalidate only the generated deployment state
    # when upstream data, generated dictionaries, or local customizations change.
    ".local/share/fcitx5/rime/.rime-crane-config-id" = {
      text = rime-crane-config-id;
      onChange = ''
        rime_user_data_dir=${lib.escapeShellArg rime-user-data-dir}
        run rm -rf -- "$rime_user_data_dir/build"
        run rm -f -- "$rime_user_data_dir/user.yaml"
      '';
    };
  };

  # Clone the dictionary repository on a new machine. Failure (offline, no
  # SSH key yet) only warns; clone it by hand later and redeploy Rime.
  home.activation.cloneXhupDictionaries = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    dictionary_dir=${lib.escapeShellArg rime-user-dictionary-dir}
    if [ ! -e "$dictionary_dir" ]; then
      run mkdir -p -- "$(dirname -- "$dictionary_dir")"
      if ! GIT_SSH_COMMAND="${pkgs.openssh}/bin/ssh -o BatchMode=yes" \
        run ${lib.getExe pkgs.git} clone --quiet ${rime-user-dictionary-repo} "$dictionary_dir"; then
        warnEcho "Could not clone ${rime-user-dictionary-repo} into $dictionary_dir; Xiaohe user words are unavailable until it is cloned."
      fi
    fi
  '';

  xdg.dataFile = lib.listToAttrs
    (map
      (name:
        lib.nameValuePair "fcitx5/rime/xhup_dicts/${name}" {
          source = config.lib.file.mkOutOfStoreSymlink "${rime-user-dictionary-dir}/${name}";
          force = true;
        })
      rime-user-dictionaries);

  # Restart Fcitx5 after cache invalidation so Rime deploys the new schema
  # before it handles the next input event.
  systemd.user.services.fcitx5-daemon.Unit.X-Restart-Triggers = [ rime-crane-config-id ];
}
