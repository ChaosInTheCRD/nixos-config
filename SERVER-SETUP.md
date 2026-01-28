# Server Setup Guide

This guide covers setting up servers with this Nix configuration for both NixOS and non-NixOS systems (Ubuntu, Debian, etc.).

## NixOS Servers

For NixOS servers, the user `chaosinthecrd` is automatically provisioned by the system configuration.

### Installation

1. Install NixOS with a minimal profile
2. Clone this repository:
   ```bash
   git clone https://github.com/chaosinthecrd/nixos-config.git /etc/nixos-config
   ```

3. Apply the configuration:
   ```bash
   # For x86_64 servers
   sudo nixos-rebuild switch --flake /etc/nixos-config#server

   # For ARM64 servers
   sudo nixos-rebuild switch --flake /etc/nixos-config#server-arm64
   ```

The configuration will:
- Create the `chaosinthecrd` user with sudo access
- Install mosh, SSH, and essential tools
- Configure firewall rules for mosh
- Set up home-manager for the user

## Non-NixOS Servers (Ubuntu, Debian, etc.)

For non-NixOS systems, you have two options:

### Option 1: Automated Bootstrap (Requires Root)

This script will create the user and install everything:

```bash
curl -L https://raw.githubusercontent.com/chaosinthecrd/nixos-config/master/bootstrap-server.sh | sudo bash
```

This will:
- Create the `chaosinthecrd` user if it doesn't exist
- Install Nix in multi-user mode
- Clone this repository
- Install and configure home-manager

**Note:** The user is created with password `changeme` - change it immediately after setup!

### Option 2: Manual Setup (For Existing User)

If the `chaosinthecrd` user already exists, run this as that user:

```bash
curl -L https://raw.githubusercontent.com/chaosinthecrd/nixos-config/master/install-home-manager.sh | bash
```

This will:
- Install Nix in single-user mode
- Clone this repository to `~/.config/nixos-config`
- Install and configure home-manager
- Apply the server home-manager configuration

### Manual User Creation

If you prefer to create the user manually first:

```bash
# Create user with home directory
sudo useradd -m -s /bin/bash -G sudo chaosinthecrd

# Set password
sudo passwd chaosinthecrd

# Add sudo permissions
echo "chaosinthecrd ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/chaosinthecrd
sudo chmod 0440 /etc/sudoers.d/chaosinthecrd
```

Then run Option 2 above as the `chaosinthecrd` user.

## Post-Installation

### Update Configuration

To update the configuration on any server:

```bash
cd ~/.config/nixos-config  # or /etc/nixos-config for NixOS
git pull

# For NixOS:
sudo nixos-rebuild switch --flake .#server

# For non-NixOS with home-manager:
home-manager switch --flake .#chaosinthecrd
```

### Mosh Connection

Connect to your server using mosh:

```bash
mosh chaosinthecrd@your-server
```

If you encounter issues with mosh not finding the server binary, you can explicitly specify it:

```bash
mosh --server=/run/current-system/sw/bin/mosh-server chaosinthecrd@your-server  # NixOS

# For non-NixOS, mosh-server will be in:
mosh --server=$HOME/.local/state/nix/profiles/home-manager/home-path/bin/mosh-server chaosinthecrd@your-server
```

### SSH Keys

Don't forget to copy your SSH public key to the server:

```bash
ssh-copy-id chaosinthecrd@your-server
```

## What Gets Installed

### NixOS Servers
- System packages: neovim, git, wget, curl
- mosh (system-wide via `programs.mosh.enable`)
- Docker
- Firewall configured for SSH and mosh

### Non-NixOS Servers (via home-manager)
- Core CLI tools: fzf, ripgrep, bat, htop, tree, jq, etc.
- Shell: zsh with configuration
- Editor: neovim with configuration
- Development tools: git, gcc, make, go
- Kubernetes tools: kubectl, k9s, helm, etc.
- mosh (user-level)

## Troubleshooting

### Nix Commands Not Found

Source the Nix profile:

```bash
# Single-user installation
. ~/.nix-profile/etc/profile.d/nix.sh

# Multi-user installation
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
```

### Home-manager Not Found

Install it manually:

```bash
nix run home-manager/master -- init --switch
```

### Mosh Connection Issues

Ensure:
1. Mosh is installed on both client and server
2. UDP ports 60000-61000 are open in the firewall
3. The server binary is in the PATH or explicitly specified

For Ubuntu/Debian servers, open the firewall:

```bash
sudo ufw allow 60000:61000/udp
```
