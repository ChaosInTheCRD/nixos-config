#
# Direnv for Home Manager
#
# Home Manager compatible version without system-level options

{ config, lib, pkgs, ... }:

{
  # Use home-manager's direnv module
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };

  # Add packages to home
  home.packages = with pkgs; [
    direnv
    nix-direnv
  ];
}
