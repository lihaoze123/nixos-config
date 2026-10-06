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

      # jj-starship 统一处理 Git 和 Jujutsu 仓库，关闭内置 git 模块避免重复显示
      git_branch.disabled = true;
      git_commit.disabled = true;
      git_status.disabled = true;
      custom.jj = {
        when = "${pkgs.jj-starship}/bin/jj-starship detect";
        command = "${pkgs.jj-starship}/bin/jj-starship";
        shell = [ "sh" ];
        format = "$output ";
      };
    };
  };

  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
  };
}
