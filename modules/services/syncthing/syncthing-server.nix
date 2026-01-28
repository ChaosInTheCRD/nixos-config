{ lib, pkgs, ... }:

{
  services.syncthing = {
    enable = true;
    tray.enable = false;
    extraOptions = [
      "--gui-address=0.0.0.0:8384"
    ];
  };

  # Configure syncthing to listen on default port 22000
  home.file.".config/syncthing/config.xml".onChange = ''
    ${pkgs.syncthing}/bin/syncthing cli config options listen-address set "default" || true
  '';
}
