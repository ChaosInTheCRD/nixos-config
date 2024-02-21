{ pkgs, ... }:
with pkgs;

{
  home = {
    packages = with pkgs; [
      # Command-line tools
      witness cosign syft grype 
    ];
  };
}
