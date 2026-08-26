{ pkgs, ... }:
with pkgs;

{
  home = {
    packages = with pkgs; [
      # Command-line tools (cross-platform)
      git-crypt cargo yarn protobuf docker goreleaser vulnix hugo vcluster
      istioctl go_1_26 scorecard python3 niv golangci-lint gh protoc-gen-go

      ## Tools that I have needed to install in weird circumstances. I don't actually write
      ## hehehe
      openjdk maven

      # vibes
      # NOTE: claude-code comes from the Homebrew cask (auto-updates), NOT nixpkgs.
      # nixpkgs lags, and paseo hides the newest models when its resolved `claude`
      # is below each model's minimumClaudeCodeVersion (Opus 5 needs >= 2.1.219).
      gemini-cli
    ];
  };
}

