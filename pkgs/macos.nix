# macOS-specific packages
{ pkgs, ... }:

{
  home = {
    packages = with pkgs; [
      colima
      lima
    ];
  };
}
