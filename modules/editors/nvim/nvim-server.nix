# Server-friendly nvim config
# Copies LazyNvim config into Nix store instead of out-of-store symlink
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    neovim
  ];

  # Copy the entire LazyNvim config directory to ~/.config/nvim
  # This is Nix-friendly as it copies into the store rather than symlinking out of it
  xdg.configFile."nvim".source = ./LazyNvim;
}
