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

  # No GUI, no graphical services
  # Just shell and SSH access
}
