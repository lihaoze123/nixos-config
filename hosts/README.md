# Hosts Configuration

This directory contains NixOS configurations for different devices (hosts).

## Structure

Each host has its own directory containing:

- `default.nix` - Main host configuration that imports all necessary modules
- `hardware-configuration.nix` - Hardware-specific configuration (auto-generated)
- `features.nix` - Feature switches for this host (options default to off; existing hosts enable what they had before)
- `optional files` - Additional host-specific configurations

## Current Hosts

- `laptop/` - Laptop configuration with mobile-specific settings
- `class/` - Minimal base-derived system with Btrfs partitions alongside Windows; see [installation guide](../docs/class-installation.md)
- `home/` - Home desktop with NVIDIA, printing and Syncthing
- `base/` - Minimal configuration for installing a new machine
- `installer/` - Standalone minimal live ISO with root SSH access using the laptop public key

## Adding a New Host

1. Create a new directory: `mkdir hosts/new-host`
2. Copy and adapt an existing `default.nix`
3. Generate hardware configuration: `sudo nixos-generate-config`
4. Copy `hardware-configuration.nix` to the new host directory
5. Update `flake.nix` to include the new host
6. Create home-manager configuration if needed

## Usage

Build configuration for a specific host:
```bash
nixos-rebuild build --flake .#hostname
```

`base` is a standalone minimal configuration for new machines, not a variant of another host. Replace `base/hardware-configuration.nix` (a placeholder) with the target machine's generated one before installing.
See [分阶段安装指南](../docs/installation-profiles.md) for profile applications and project devShells.

`installer` imports the upstream installation CD module directly and needs no generated hardware configuration or feature switches.
Build it with `nix build .#installer-iso --out-link result-installer`; see the [自定义安装镜像](../README.md#自定义安装镜像) instructions for writing and booting the ISO.
