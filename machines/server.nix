# Server/headless machine configuration
# Minimal configuration focused on shell and CLI tools
{ config, pkgs, lib, ... }:

{
  networking.hostName = "nixos-server";

  # Basic system packages for a server environment
  environment.systemPackages = with pkgs; [
    neovim
    git
    wget
    curl
    htop
    tmux
    killall
    bash
  ];

  services.syncthing = {
    enable = true;
    user = "chaosinthecrd";
    dataDir = "/home/chaosinthecrd/.syncthing";
    configDir = "/home/chaosinthecrd/.config/syncthing";
    overrideDevices = true;
    overrideFolders = true;
    settings = {
      devices = {
        "macbook" = {
          id = "YOUR-MACBOOK-DEVICE-ID-HERE";  # Get this from Syncthing GUI on macbook
        };
      };
      folders = {
        "corp" = {
          path = "/home/chaosinthecrd/code/corp";
          devices = [ "macbook" ];
          ignorePerms = false;
        };
        "tailscale" = {
          path = "/home/chaosinthecrd/code/tailscale";
          devices = [ "macbook" ];
          ignorePerms = false;
        };
      };
      options = {
        urAccepted = -1;  # Disable usage reporting
      };
    };
  };

  # No GUI, no graphical services
  # Just shell and SSH access
}
