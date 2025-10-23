# Hosts Configuration

This directory contains NixOS configurations for different devices (hosts).

## Structure

Each host has its own directory containing:

- `default.nix` - Main host configuration that imports all necessary modules
- `hardware-configuration.nix` - Hardware-specific configuration (auto-generated)
- `optional files` - Additional host-specific configurations

## Current Hosts

- `laptop/` - Laptop configuration with mobile-specific settings
- `class/` - Classroom/office configuration with desktop-specific settings

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
sudo nixos-rebuild switch --flake .#hostname
```