# Incrementally add modules to find what breaks arm64
{ pkgs, ... }:

{
  home = {
    username = builtins.getEnv "USER";
    homeDirectory = builtins.getEnv "HOME";
    stateVersion = "23.05";

    packages = with pkgs; [
      neovim
      git
      htop
      fzf
    ];
  };

  # Add imports one at a time below and test
  imports = [
    # ./pkgs/core.nix  # Test 1: uncomment this first
    # ./pkgs/dev.nix   # Test 2: then this
    # ./pkgs/kube.nix  # Test 3: then this
  ];

  programs.zsh = {
    enable = true;
  };
}
