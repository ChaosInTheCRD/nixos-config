{ config, lib, ... }:

let
  nixConfigDir = "${config.home.homeDirectory}/Git/nixos-config";
  inherit (config.lib.file) mkOutOfStoreSymlink;
in

{
  # Config -------------------------------------------------------------------------
  xdg.configFile."nvim".source = mkOutOfStoreSymlink "${nixConfigDir}/modules/editors/nvim/LazyNvim";

  # home-manager's programs.neovim auto-generates xdg.configFile."nvim/init.lua"
  # from the wrapper's luaRcContent, which collides with the LazyNvim directory
  # symlink above. Suppress it so LazyNvim's own init.lua wins.
  xdg.configFile."nvim/init.lua".enable = lib.mkForce false;
}
