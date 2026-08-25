{ config, lib, osConfig ? null, ... }:

let
  nixConfigDir = "${config.home.homeDirectory}/Git/nixos-config";
  inherit (config.lib.file) mkOutOfStoreSymlink;
  isGuest = if osConfig == null then false else (osConfig.tailvisor.guest or false);
in

{
  # Operational guide loaded by every Claude Code session on the guest
  # (~/.claude/CLAUDE.md): how to deploy the iOS app, host<->guest clipboard,
  # git signing, `make switch`, paseo, etc. Symlinked from the repo so edits are
  # live and version-controlled. Guest-only — the content is VM-specific.
  home.file.".claude/CLAUDE.md" = lib.mkIf isGuest {
    source = mkOutOfStoreSymlink "${nixConfigDir}/darwin/modules/claude/CLAUDE.md";
  };
}
