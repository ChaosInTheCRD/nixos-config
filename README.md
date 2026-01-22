# NixOS Configuration

Personal NixOS and Darwin system configuration with Flakes.

## Quick Start

### For Linux Servers

See [SERVER_SETUP.md](SERVER_SETUP.md) for detailed instructions on setting up a headless/server configuration with shell tools only.

Quick start:
```bash
git clone <this-repo>
cd nixos-config
make install  # Install Nix if needed
make switch   # Build and apply server configuration
```

### For Desktop/Laptop

Use the standard NixOS or Darwin configurations:
```bash
make switch NIXNAME=desktop    # For NixOS desktop
make switch NIXNAME=macbook-m1 # For macOS M1
```

## Provisioning GPG Key

This is a step that I forget how to do every time I have to do it, so to avoid that:

1. `gpg --edit-card`
2. `fetch`
3. That should be it
