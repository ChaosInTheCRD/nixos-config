{ config, osConfig, lib, ... }:

let
  nixConfigDir = "${config.home.homeDirectory}/Git/nixos-config";
  inherit (config.lib.file) mkOutOfStoreSymlink;
  isGuest = osConfig.tailvisor.guest or false;
in

{
  # Config and widgets ------------------------------------------------------------------------- {{{
  xdg.configFile."kitty".source = mkOutOfStoreSymlink "${nixConfigDir}/darwin/modules/kitty/config";

  # Tailvisor VM marker: leafy-teal override the base config optionally
  # globincludes. Only written inside the guest, so the host keeps its theme.
  home.file.".config/kitty-vm.conf" = lib.mkIf isGuest {
    text = ''
      # Tailvisor VM — leafy green / teal accent
      background #0f1f1c
      cursor #8bd5ca
      cursor_text_color #0f1f1c
      selection_background #274b45
      selection_foreground #cad3f5
      color0 #0f1f1c
    '';
  };
}
