{ config, pkgs, user, ... }: {

  networking = {
    computerName = "Toms MacBook";             # Host name
    hostName = "toms-macbook";
  };

    fonts.packages = [
      pkgs.nerd-fonts.jetbrains-mono
    ];

}
