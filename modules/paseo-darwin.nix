# Paseo daemon for the tailvisor macOS guest — the darwin analog of the Linux
# LLM VM's systemd user service (modules/llm-vm.nix). Runs paseo-server as a
# launchd user agent. Runtime paseo state (~/.paseo/config.json: listen address,
# hostnames, password) is owned by the daemon/CLI and deliberately NOT managed
# here, exactly as on Linux.
#
# Imported as a factory (`import ... { inherit paseoPackage; }`) so the guest can
# hand it the darwin paseo build; the physical macbooks pass no paseoPackage and
# so never get the daemon.
{ paseoPackage }:
{ config, lib, ... }:

let
  homeDir = config.home.homeDirectory;
  user = config.home.username;

  # PATH for paseo and the agent processes it spawns (git, node, claude, …).
  # ~/.local/bin first, then the home-manager/nix-darwin user profiles, then
  # Homebrew and system paths. Mirrors the Linux paseoPath, adapted for darwin.
  paseoPath = lib.concatStringsSep ":" [
    "${homeDir}/.local/bin"
    "${homeDir}/.nix-profile/bin"
    "/etc/profiles/per-user/${user}/bin"
    "/run/current-system/sw/bin"
    "/nix/var/nix/profiles/default/bin"
    "/opt/homebrew/bin"
    "/usr/local/bin"
    "/usr/bin"
    "/bin"
  ];
in
{
  home.packages = [ paseoPackage ];

  launchd.agents.paseo = {
    enable = true;
    config = {
      ProgramArguments = [ "${paseoPackage}/bin/paseo-server" ];
      EnvironmentVariables = {
        NODE_ENV = "production";
        PASEO_HOME = "${homeDir}/.paseo";
        PATH = paseoPath;
        # Bind + host-allowlist via env, not config.json: the paseo *cask*
        # (a newer version) keeps rewriting ~/.paseo/config.json in its own
        # format, which drops these. paseo merges PASEO_LISTEN / PASEO_HOSTNAMES
        # on top of config.json, so the env wins regardless. 0.0.0.0 is required
        # because the hypervisor's inbound proxy dials the guest's virtio IP;
        # the *.ts.net allowlist lets the tailnet MagicDNS Host header through
        # paseo's DNS-rebinding guard.
        PASEO_LISTEN = "0.0.0.0:6767";
        PASEO_HOSTNAMES = "tailvisor.tail7373cb.ts.net,*.ts.net";
      };
      RunAtLoad = true;
      # launchd analog of systemd Restart=on-failure: relaunch unless it exited 0.
      KeepAlive = { SuccessfulExit = false; };
      ThrottleInterval = 5;
      StandardOutPath = "${homeDir}/Library/Logs/paseo.log";
      StandardErrorPath = "${homeDir}/Library/Logs/paseo.err.log";
    };
  };
}
