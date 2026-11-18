# Minimal system for a new machine: boot, network, user, SSH, shell and editor.
# Every my.* switch keeps its default (off). To add a desktop, import
# ../../profiles/workstation.nix; see modules/<domain>/ for all switches.
{ ... }:
{
  imports = [ ./hardware-configuration.nix ];
}
