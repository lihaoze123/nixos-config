# Hosts Configuration

This directory contains NixOS configurations for different devices (hosts).

## Structure

Each host has its own directory containing:

- `default.nix` - Imports a profile from `../profiles`, overrides `my.*` switches (declared in `../modules/options.nix`, all off by default) and holds host-only settings
- `hardware-configuration.nix` - Hardware-specific configuration (auto-generated)
- `home.nix` - Optional Home Manager overrides for this host
- `optional files` - Additional host-specific configuration (hardware quirks, single-host services)

Shared modules, Home Manager and the host name are wired in by `mkHost` in `../lib/default.nix`.

## Current Hosts

- `laptop/` - Laptop configuration with mobile-specific settings
- `class/` - Minimal base-derived system with Btrfs partitions alongside Windows; see [installation guide](../docs/class-installation.md)
- `home/` - Home desktop with NVIDIA, printing and Syncthing
- `base/` - Minimal configuration for installing a new machine
- `installer/` - Standalone minimal live ISO with root SSH access using the laptop public key

## Adding a New Host

1. Create a new directory: `mkdir hosts/new-host`
2. Copy `base/default.nix` and import a profile (e.g. `../../profiles/workstation.nix`)
3. Generate hardware configuration: `sudo nixos-generate-config`
4. Copy `hardware-configuration.nix` to the new host directory
5. Add `nixosConfigurations.new-host = mkHost "new-host";` to `flake.nix`
6. Add `home.nix` and `home-manager.users.chumeng.imports = [ ./home.nix ];` if the host needs Home Manager overrides

## Usage

Build configuration for a specific host:
```bash
nixos-rebuild build --flake .#hostname
```

`base` is a standalone minimal configuration for new machines, not a variant of another host. Replace `base/hardware-configuration.nix` (a placeholder) with the target machine's generated one before installing.
See [安装入口、功能开关与应用](../docs/installation-profiles.md) for profiles, switches, applications and project devShells.

`installer` imports the upstream installation CD module directly and needs no generated hardware configuration or feature switches.
Build it with `nix build .#installer-iso --out-link result-installer`; see the [自定义安装镜像](../README.md#自定义安装镜像) instructions for writing and booting the ISO.
