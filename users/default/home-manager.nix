{ lib, pkgs, paseoPackage ? null, ... }:

let
  isDarwin = pkgs.stdenv.isDarwin;
  isLinux = pkgs.stdenv.isLinux;

in {

  imports = [
        ../../modules/shell/git.nix
        ../../modules/shell/zsh.nix
        ../../modules/editors/nvim/nvim.nix
        ../../modules/archive-downloads/archive-downloads.nix
        ../../pkgs/default.nix
        ../../darwin/modules/kitty/kitty.nix
        ../../darwin/modules/ghostty/ghostty.nix
        ] ++ (lib.optionals pkgs.stdenv.isDarwin [
        ../../modules/ios-deploy
        ../../darwin/modules/clipboard-sync.nix
        ../../darwin/modules/sketchybar/sketchybar.nix
        ../../darwin/modules/yabai/yabai.nix
        ../../darwin/modules/skhd/skhd.nix
        ../../darwin/modules/syncthing/syncthing.nix
        ../../pkgs/macos.nix
        ]) ++ (lib.optionals (paseoPackage != null && pkgs.stdenv.isDarwin) [
        (import ../../modules/paseo-darwin.nix { inherit paseoPackage; })
        ]) ++ (lib.optionals pkgs.stdenv.isLinux [
        ../../modules/desktop/hyprland/home.nix
        ../../pkgs/nixos.nix
        ../../modules/desktop/hyprland/extras.nix
        ../../modules/desktop/dunst/dunst.nix
        ../../modules/vm/vfio/default.nix
        ../../pkgs/linux.nix
        ]);

  home = {
    stateVersion = "23.05";
    # Skip Homebrew's third-party tap-trust prompt (FelixKratz / koekeishiya /
    # theseal taps) so brew installs don't need manual trust each time.
    sessionVariables.HOMEBREW_NO_REQUIRE_TAP_TRUST = "1";
  };
}
