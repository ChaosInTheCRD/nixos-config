# Linux-specific packages
{ pkgs, ... }:

{
  home = {
    packages = with pkgs; [
      # Add any Linux-only tools here
    ];
  };
}
