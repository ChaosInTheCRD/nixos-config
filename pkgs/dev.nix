{ pkgs, ... }:
with pkgs;

{
  home = {
    packages = with pkgs; [
      # Command-line tools
      git-crypt cargo yarn protobuf lima goreleaser vulnix protobuf hugo vcluster
      istioctl go scorecard python3 niv golangci-lint gh

      ## Tools that I have needed to install in weird circumstances. I don't actually write
      ## hehehe
      openjdk maven
    ];
  };
}
