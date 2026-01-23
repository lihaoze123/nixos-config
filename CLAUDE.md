# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with this NixOS configuration repository.

## User Environment

**Operating System**: NixOS
**Package Manager**: Nix with flakes enabled
**Configuration Style**: Modular flake-based NixOS + Home Manager

## Critical Requirements

### Script Shebang Format

When creating executable scripts in this NixOS environment:

**❌ WRONG**:
```bash
#!/bin/bash
#!/usr/bin/env python3
```

**✅ CORRECT**:
```bash
#!/usr/bin/env bash
#!/usr/bin/env python3
```

**Why**: On NixOS, binaries are not in traditional Unix paths (`/bin`, `/usr/bin`). They are stored in the Nix store (`/nix/store/...`). Using `/usr/bin/env` ensures scripts work because:
1. `env` is always available in the user's PATH
2. PATH is properly set up by NixOS to include all package binaries
3. Scripts remain portable across different systems

**Examples of correct shebangs**:
- `#!/usr/bin/env bash` - Bash scripts
- `#!/usr/bin/env sh` - POSIX shell scripts
- `#!/usr/bin/env python3` - Python scripts
- `#!/usr/bin/env node` - Node.js scripts
- `#!/usr/bin/env nix-shell` - Nix shell scripts

## Configuration Structure

### Directory Layout

```
nixos-config/
├── flake.nix                    # Top-level flake with all inputs
├── flake.lock                   # Pinned input versions
├── hosts/                       # Host-specific configurations
│   ├── home/
│   │   ├── default.nix         # Host configuration
│   │   ├── hardware-configuration.nix  # Generated (DO NOT EDIT)
│   │   └── home.nix            # Home Manager user config
│   ├── laptop/
│   └── class/
├── home-manager/                # Shared Home Manager configs
│   ├── shell/
│   ├── applications/
│   └── common.nix
├── modules/                     # Reusable NixOS modules
├── overlays/                    # Custom package overlays
└── secrets/                     # Age-encrypted secrets
```

### Key Configuration Files

- **flake.nix**: Defines all flake inputs and outputs
- **hosts/base.nix**: Shared NixOS configuration for all hosts
- **home-manager/home.nix**: Home Manager imports and base config

## Important Patterns

### Overlay Scope with useGlobalPkgs

This configuration uses `home-manager.useGlobalPkgs = true` for efficiency.

**CRITICAL**: When `useGlobalPkgs = true`, overlays must be defined in the host's home-manager configuration block, NOT in `home.nix`:

```nix
# ✅ CORRECT: In hosts/home/default.nix
{
  home-manager.useGlobalPkgs = true;
  home-manager.users.chumeng = import ./home.nix;
  home-manager.nixpkgs.overlays = [ inputs.some-overlay.overlays.default ];
}

# ❌ WRONG: In home-manager/home.nix
{
  nixpkgs.overlays = [ inputs.some-overlay.overlays.default ];  # Ignored!
}
```

### Flake Inputs Pattern

All flake inputs are passed via `specialArgs`:

```nix
# flake.nix
outputs = { self, nixpkgs, home-manager, ... }@inputs:
{
  nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
    specialArgs = { inherit inputs; };
    modules = [ ./hosts/myhost ];
  };
};
```

Then available in modules:
```nix
# hosts/myhost/default.nix
{ inputs, pkgs, ... }:
{
  imports = [
    inputs.home-manager.nixosModules.home-manager
  ];
}
```

### Package Installation Locations

- **System packages**: `environment.systemPackages` in host config or base.nix
- **User packages**: `home.packages` in Home Manager config
- **System services**: `services.*` in NixOS config
- **User services**: `services.*` in Home Manager config

## Build Commands

```bash
# Test configuration (build without activating)
nixos-rebuild build --flake .#hostname

# Apply configuration
sudo nixos-rebuild switch --flake .#hostname

# Test configuration (rollback on reboot)
sudo nixos-rebuild test --flake .#hostname

# Update flake inputs
nix flake update

# Check configuration
nix flake check
```

## Common Tasks

### Adding a New Package

1. Determine if it's a system package or user package
2. Add to appropriate location:
   - System: `environment.systemPackages = with pkgs; [ package-name ];`
   - User: `home.packages = with pkgs; [ package-name ];`
3. Rebuild: `sudo nixos-rebuild switch --flake .#hostname`

### Adding a Flake Input

1. Add to `inputs` in flake.nix
2. Update flake.lock: `nix flake update`
3. Use in configuration: reference via `inputs.input-name`

### Creating a New Host

1. Copy existing host directory
2. Run `sudo nixos-generate-config --root /mnt --dir ./hosts/new-host`
3. Update `hardware-configuration.nix`
4. Customize `default.nix` for the host
5. Add host to flake.nix outputs

## Troubleshooting

### Overlay Not Applied

If a package from an overlay is "not found":
1. Check if overlay is defined in correct location (host home-manager block)
2. Verify `useGlobalPkgs` setting
3. Check overlay syntax: `inputs.overlay.overlays.default`
4. Rebuild system (not just home-manager)

See also: `~/.claude/skills/nixos-best-practices/` for detailed NixOS configuration best practices.

### Configuration Changes Not Applying

1. Ensure rebuild succeeded: check for "success" message
2. Verify new generation is active: `nixos-version`
3. Check if service needs restart: `systemctl restart service-name`

### Shell Script Not Found

If script fails with "command not found":
1. Check shebang uses `/usr/bin/env` format
2. Ensure script interpreter is installed (in PATH or environment.systemPackages)
3. Verify script has execute permissions: `chmod +x script.sh`

## Development Guidelines

- Don't edit `hardware-configuration.nix` - it's regenerated by `nixos-generate-config`
- Put custom hardware config in the host's `default.nix`
- Use relative paths for local files
- Follow the modular structure for maintainability
- Test with `build` before `switch` to catch errors early

## Related Documentation

- NixOS Manual: https://nixos.org/manual/nixos/stable/
- Home Manager Manual: https://nix-community.github.io/home-manager/
- NixOS & Flakes: https://nixos.wiki/wiki/Flakes
- Local skills: `~/.claude/skills/nixos-best-practices/`
