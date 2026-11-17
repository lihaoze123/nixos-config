{ config, lib, pkgs, osConfig, myLib, ... }:
let
  cleanupLegacyCredentials = pkgs.writeShellApplication {
    name = "cleanup-legacy-doubao-credentials";
    runtimeInputs = [ pkgs.python3 ];
    text = ''
      exec python3 ${./scripts/doubao-asr-worker.py} \
        --credentials "${config.age.secrets.doubao-asr.path}" \
        --local-worker /dev/null \
        --remove-legacy ${lib.escapeShellArg "${config.xdg.configHome}/vocotype/doubao-asr.json"}
    '';
  };
in
{
  options.programs.vocotype.doubao.enable =
    lib.mkEnableOption "Doubao ASR 2.0 with agenix-managed credentials";

  config = lib.mkMerge [
    {
      programs.vocotype.doubao.enable = osConfig.my.desktop.input.speech.doubao.enable;
    }
    (lib.mkIf config.programs.vocotype.doubao.enable {
      age.secrets.doubao-asr.file = myLib.secret "doubao-asr.age";
      # Home Manager's agenix decrypts in a user unit. Clean up only after the
      # decrypted credentials are available and match the legacy plaintext.
      systemd.user.services.agenix.Service.ExecStartPost = lib.getExe cleanupLegacyCredentials;
      systemd.user.services.agenix.Unit.X-Restart-Triggers = [
        (builtins.hashFile "sha256" (myLib.secret "doubao-asr.age"))
      ];
    })
  ];
}
