{ config, pkgs, ... }:
{
  programs.fish = {
    enable = true;
    shellInit = ''
      source ${./config.fish}
    '';
  };

  programs.bash = {
    enable = true;
    initExtra = ''
      if [[ $(${pkgs.procps}/bin/ps --no-header --pid=$PPID --format=comm) != "fish" && -z ''${BASH_EXECUTION_STRING} ]]
      then
        shopt -q login_shell && LOGIN_OPTION='--login' || LOGIN_OPTION=""
        exec ${pkgs.fish}/bin/fish $LOGIN_OPTION
      fi
    '';
  };

  programs.starship = {
    enable = true;
    enableFishIntegration = true;
    settings = {
      add_newline = true;
      character.success_symbol = "[~](bold green)";
    };
  };

  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
  };
}
