{ config, lib, pkgs, inputs, ... }:
{
    imports = [
        inputs.daeuniverse.nixosModules.dae
    ];

    age.secrets.dae-subscription = {
        file = ../../secrets/dae-subscription.age;
    };

    services.dae = {
        enable = true;

        openFirewall = {
            enable = true;
            port = 12345;
        };

        config = builtins.replaceStrings ["NIX_REPLACE_SUBSCRIPTION_HERE"] [(lib.strings.removeSuffix "\n" (builtins.readFile config.age.secrets.dae-subscription.path))] (builtins.readFile ./config.dae);
    };
}
