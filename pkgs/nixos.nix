{ pkgs, ... }:
with pkgs;

{
  home = {
    packages = with pkgs; [
      spotify bitwarden _1password-gui pavucontrol pamixer lsof wtype slack thunderbird-unwrapped pamixer
      plex-media-player cartridges gwenview mailspring playerctl docker
      google-chrome gnupg gpg-tui yubikey-manager ssh-askpass-fullscreen lxqt.lxqt-openssh-askpass
      libsForQt5.ksshaskpass nwg-look swaybg wpaperd nodejs openssl qpwgraph

      nordpass waterfox
      ];

    pointerCursor = {
      gtk.enable = true;
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Ice";
      size = 22;
    };
  };
}
