{ config, lib, pkgs, inputs, ... }:
{
  imports = [
    inputs.hermes-agent.nixosModules.default
  ];

  services.hermes-agent = {
    enable = true;
    addToSystemPackages = true;
    container = {
      enable = true;
      extraVolumes = [ "/home/chumeng/Documents/.obsidian/Notes:/home/hermes/obsidian:rw" ];
    };
    environmentFiles = [ config.age.secrets.hermes-env.path ];
    settings = {
      model = {
        provider = "minimax-cn";
        default = "MiniMax-M2.7";
      };

      toolsets = [ "all" ];
    };
  };

  age.secrets.hermes-env = {
    file = ../../secrets/hermes-env.age;
  };
}
