## Essentially the shared `configuration.nix` for all the machines (including darwin)
{ config, pkgs, lib, ... }:

{
  fonts = {
    fontDir.enable = true;
    packages = with pkgs; [
      source-code-pro
      font-awesome
      (nerdfonts.override {
        fonts = [
          "JetBrainsMono"
        ];
      })
    ];
  };

  nix = {
    settings = {
      trusted-users = [ "chaosinthecrd" "root" ];
    };
    package = pkgs.nix;
    gc = {                                # Garbage collection
      automatic = true;
      options = "--delete-older-than 7d";
    };
    extraOptions = ''
      auto-optimise-store = true
      experimental-features = nix-command flakes
    '';
  };
}
