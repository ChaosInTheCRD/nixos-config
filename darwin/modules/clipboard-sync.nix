#
#  Seamless host <-> guest clipboard for the tailvisor macOS guest.
#
#  The hypervisor exposes the HOST Mac's clipboard over HTTP on the guest-only
#  gateway (192.168.72.1:9550). This agent polls it about twice a second and
#  mirrors whichever side most recently changed, so plain cmd+c / cmd+v works
#  across both machines with no key interception. Text-only (the bridge is
#  text-only) and guest-only (osConfig.tailvisor.guest gates it; the host has
#  no such gateway).
#
{ config, lib, pkgs, osConfig ? null, ... }:

let
  isGuest = if osConfig == null then false else (osConfig.tailvisor.guest or false);
  endpoint = "http://192.168.72.1:9550/clipboard";

  # Track the guest pasteboard and the host clipboard separately, seeded from
  # their current values so startup never clobbers either side. On a real
  # change we push/pull and set BOTH trackers to the new value, so the echo
  # coming back from the other side isn't mistaken for a fresh change (no
  # feedback loop). Empty reads are ignored so copying an image — which yields
  # no text — doesn't wipe the shared clipboard.
  syncScript = pkgs.writeShellScript "tailvisor-clipboard-sync" ''
    set -u
    endpoint="${endpoint}"

    last_guest="$(/usr/bin/pbpaste 2>/dev/null || true)"
    last_host="$(/usr/bin/curl -s --max-time 2 "$endpoint" 2>/dev/null || true)"

    while :; do
      guest="$(/usr/bin/pbpaste 2>/dev/null || true)"
      host="$(/usr/bin/curl -s --max-time 2 "$endpoint" 2>/dev/null || true)"

      if [ -n "$guest" ] && [ "$guest" != "$last_guest" ]; then
        printf '%s' "$guest" | /usr/bin/curl -s --max-time 2 --data-binary @- "$endpoint" >/dev/null 2>&1
        last_guest="$guest"
        last_host="$guest"
      elif [ -n "$host" ] && [ "$host" != "$last_host" ]; then
        printf '%s' "$host" | /usr/bin/pbcopy
        last_host="$host"
        last_guest="$host"
      fi

      /bin/sleep 0.5
    done
  '';
in
{
  launchd.agents.clipboard-sync = lib.mkIf isGuest {
    enable = true;
    config = {
      ProgramArguments = [ "${syncScript}" ];
      RunAtLoad = true;
      KeepAlive = true;                 # relaunch if it ever dies
      ThrottleInterval = 5;
      StandardOutPath = "${config.home.homeDirectory}/Library/Logs/clipboard-sync.log";
      StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/clipboard-sync.err.log";
    };
  };
}
