{ pkgs, ... }:
with pkgs;

{
  home = {
    packages = with pkgs; [
      # Command-line tools
      git-crypt cargo yarn protobuf lima goreleaser vulnix protobuf hugo vcluster
      istioctl go
    ];
  };
}
