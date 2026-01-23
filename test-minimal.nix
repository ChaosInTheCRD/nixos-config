# Absolute minimal test config
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

  programs.zsh = {
    enable = true;
  };
}
