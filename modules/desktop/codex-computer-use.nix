{ config, pkgs, lib, inputs, ... }:
let
  cfg = config.my.desktop.codexComputerUse;
  desktopPackages = inputs.nur-desktop.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  imports = [
    inputs.nur-desktop.nixosModules.computer-use
  ];

  options.my.desktop.codexComputerUse.enable = lib.mkEnableOption "Codex Desktop Computer Use integration";

  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = !cfg.enable || config.my.desktop.enable;
          message = "my.desktop.codexComputerUse requires my.desktop";
        }
      ];
    }
    (lib.mkIf config.my.desktop.enable {
      # The imported module otherwise rebuilds niri with the host's pkgs.
      # Keep its feature flags while selecting the exact CI-cached package set.
      programs.niri.package = lib.mkIf (config.programs.codexComputerUse.enable && config.programs.codexComputerUse.patchNiri)
        (lib.mkForce (desktopPackages.niri-patched.override {
          agentInput = config.programs.codexComputerUse.agentInput;
        }));

      # Share the desktop and native niri backend across hosts.
      programs.codexComputerUse = {
        enable = cfg.enable;
        users = [ config.my.user.name ];
        package = desktopPackages.codex-desktop;
      };
    })
    (lib.mkIf cfg.enable {
      my.home = lib.setDefaultModuleLocation ./codex-computer-use.nix {
        xdg.configFile."niri/computer-use.kdl".text = ''
          // Indicate windows driven by a computer-use agent (niri-computer-use agent
          // input patch) with a thin indigo-violet border and a soft glow. Installed
          // only with my.desktop.codexComputerUse: stock niri rejects is-agent-driven.
          window-rule {
              match is-agent-driven=true

              border {
                  on
                  width 2
                  active-gradient from="#818cf8" to="#c084fc" angle=135
                  inactive-gradient from="#818cf8" to="#c084fc" angle=135
              }

              shadow {
                  on
                  softness 40
                  spread 3
                  offset x=0 y=0
                  color "#a78bfa70"
              }
          }
        '';
      };
    })
  ];
}
