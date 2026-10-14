{ lib, osConfig, ... }:
{
  age.identityPaths = [ "${osConfig.my.user.home}/.ssh/id_ed25519" ];
  xresources.properties."Xft.dpi" = lib.mkForce 96;
}
