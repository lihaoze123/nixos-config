{ config, lib, pkgs, inputs, ... }:
{
    imports = [
        inputs.daeuniverse.nixosModules.dae
    ];

    age.secrets.dae-config = {
        name = "config.dae";
        file = ../../secrets/dae-config.age;
    };

    services.dae = {
        enable = true;

        openFirewall = {
            enable = true;
            port = 12345;
        };

        configFile = config.age.secrets.dae-config.path;
    };
}
