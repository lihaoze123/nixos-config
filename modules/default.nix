{ ... }:
{
  # Shared by every installed host; mkHost adds the host directory.
  imports = [
    ./core
    ./hardware
    ./shell
    ./network
    ./virtualisation
    ./services
    ./desktop
    ./apps
  ];
}
