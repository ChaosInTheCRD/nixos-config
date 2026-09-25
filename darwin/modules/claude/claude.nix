{ config, lib, osConfig ? null, ... }:

let
  nixConfigDir = "${config.home.homeDirectory}/Git/nixos-config";
  inherit (config.lib.file) mkOutOfStoreSymlink;
  isGuest = if osConfig == null then false else (osConfig.tailvisor.guest or false);
in

{
  # Operational guide loaded by every coding-agent session on the guest: how to
  # deploy the iOS app, host<->guest clipboard, git signing, `make switch`,
  # paseo, etc. One source file, shipped to each agent's global-context path —
  # Claude Code reads ~/.claude/CLAUDE.md, Codex reads ~/.codex/AGENTS.md.
  # Symlinked from the repo so edits are live and version-controlled, and
  # apply to every agent at once. Guest-only — the content is VM-specific.
  home.file = lib.mkIf isGuest {
    ".claude/CLAUDE.md".source =
      mkOutOfStoreSymlink "${nixConfigDir}/darwin/modules/claude/CLAUDE.md";
    ".codex/AGENTS.md".source =
      mkOutOfStoreSymlink "${nixConfigDir}/darwin/modules/claude/CLAUDE.md";
  };
}
