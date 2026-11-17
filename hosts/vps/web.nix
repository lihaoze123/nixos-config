{ ... }:
{
  services.nginx = {
    enable = true;
    virtualHosts."cms.chumeng.xyz" = {
      enableACME = true;
      forceSSL = true;
      locations."/".return = "302 https://app.pagescms.org/";
    };
  };

  security.acme = {
    acceptTerms = true;
    defaults.email = "2595248810@qq.com";
  };

  networking.firewall.allowedTCPPorts = [ 80 443 ];
}
