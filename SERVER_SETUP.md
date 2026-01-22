# Server Setup Guide

This repository now supports building a headless/server configuration that includes only shell tools and CLI utilities, without any graphical applications.

## Quick Start on a Linux Server

1. **Clone the repository:**
   ```bash
   git clone https://github.com/yourusername/nixos-config.git
   cd nixos-config
   ```

2. **Install Nix (if not already installed):**
   ```bash
   make install
   ```

3. **Build and apply the server configuration:**
   ```bash
   make switch
   ```

   On Linux systems, this will automatically use the `server` configuration.

## What's Included in the Server Configuration

The server configuration includes:

### Shell Environment
- **zsh** with custom aliases and functions
- **git** with your configurations
- **neovim** with your custom setup
- **direnv** for directory-based environment management

### CLI Tools (from pkgs/core.nix)
- fzf, ripgrep, bat, htop, tree, wget
- jq, yq, starship, atuin
- and more...

### Development Tools (from pkgs/dev.nix)
- Docker, git-crypt, cargo, yarn
- Go, Python, protobuf, gh (GitHub CLI)
- and more...

### Kubernetes Tools (from pkgs/kube.nix)
- kubectl, kubectx, k9s, helm
- argocd, kustomize, minikube, kind
- and more...

## What's NOT Included

The server configuration excludes all GUI applications:
- No Hyprland or window manager
- No Kitty, Firefox, or other GUI apps
- No Waybar, dunst, or other desktop components
- No X11 or Wayland dependencies

## Customization

### Using on a Different Machine

If you want to customize the configuration for a specific server:

1. Create a new hardware configuration in `hardware/your-server.nix`
2. Create a new machine configuration in `machines/your-server.nix`
3. Add it to `flake.nix`:
   ```nix
   nixosConfigurations.your-server = mkServer "your-server" rec {
     inherit home-manager user nixpkgs system pkgs;
     lib = pkgs.lib;
   };
   ```
4. Build with: `make switch NIXNAME=your-server`

### Modifying Packages

Edit the package lists in:
- `pkgs/core.nix` - Core CLI tools
- `pkgs/dev.nix` - Development tools
- `pkgs/kube.nix` - Kubernetes tools

### Shell Configuration

Shell aliases and functions are in:
- `modules/shell/shell_aliases`
- `modules/shell/shell_functions`
- `modules/shell/shell_exports`

## Makefile Commands

- `make install` - Install Nix
- `make update` - Update flake inputs
- `make switch` - Build and apply configuration (auto-detects server on Linux)
- `make build-server` - Build server configuration without applying
- `make bootstrap` - Full setup (install + update + switch)
- `make help` - Show all available commands

## Troubleshooting

### Override Default Configuration

On Linux, the Makefile defaults to the `server` configuration. To use a different one:
```bash
make switch NIXNAME=desktop
```

### Hardware Configuration Issues

If the generic hardware configuration doesn't work for your system, generate one:
```bash
nixos-generate-config --show-hardware-config > hardware/my-server.nix
```

Then update the configuration name and rebuild.
