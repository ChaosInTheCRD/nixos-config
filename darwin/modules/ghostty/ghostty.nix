{ config, osConfig, lib, ... }:

let
  nixConfigDir = "${config.home.homeDirectory}/Git/nixos-config";
  inherit (config.lib.file) mkOutOfStoreSymlink;
  isGuest = osConfig.tailvisor.guest or false;
in

{
  # Ghostty terminal configuration with Catppuccin Macchiato theme
  xdg.configFile."ghostty".source = mkOutOfStoreSymlink "${nixConfigDir}/darwin/modules/ghostty/config";

  # Tailvisor VM marker: a calm leafy-teal override the base config optionally
  # includes (`config-file = ?…/ghostty-vm`). Only written inside the guest, so
  # the host terminal keeps its own theme.
  home.file.".config/ghostty-vm" = lib.mkIf isGuest {
    text = ''
      # Tailvisor VM — leafy green / teal accent
      background = #0f1f1c
      cursor-color = #8bd5ca
      cursor-text = #0f1f1c
      selection-background = #274b45
      selection-foreground = #cad3f5
      palette = 0=#0f1f1c
    '';
  };
}
