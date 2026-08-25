#
#  Paseo wiring for the tailvisor macOS guest.
#
#  The paseo app itself installs via the guest-only homebrew cask (see
#  darwin/configuration.nix). Two things make its daemon reachable from the
#  tailnet, both handled here:
#
#  1. config.json must listen on 0.0.0.0, not loopback - the hypervisor's
#     inbound proxy dials the guest's virtio IP, so a 127.0.0.1 bind refuses
#     every tailnet connection. Paseo OWNS this file at runtime (hostnames
#     and pairings accumulate as devices pair), so nix must not manage it
#     outright: activation seeds it if absent and surgically rewrites just
#     the daemon.listen field if it's wrong, leaving everything else alone.
#
#  2. The tailnet only reaches guest ports the hypervisor maps. tailvisor
#     must run with --publish (6767 or any); a LaunchAgent here requests the
#     NAT-PMP mapping from the virtual gateway and re-requests every 25min
#     (TTL 3600s), so the mapping survives indefinitely without manual
#     natpmpc runs. Harmless no-op spam if the host wasn't started with
#     --publish; the log says "not authorized" in that case.
#
{ config, lib, pkgs, user, ... }:

{
  config = lib.mkIf config.tailvisor.guest {

    # Seed/repair paseo's listen address without owning the file.
    system.activationScripts.postActivation.text = lib.mkAfter ''
      PASEO_CFG="/Users/${user}/.paseo/config.json"
      if [ ! -f "$PASEO_CFG" ]; then
        sudo -u ${user} mkdir -p "/Users/${user}/.paseo"
        cat > "$PASEO_CFG" <<'PASEOEOF'
      {
        "daemon": {
          "listen": "0.0.0.0:6767"
        }
      }
      PASEOEOF
        chown ${user}:staff "$PASEO_CFG"
        echo "paseo: seeded $PASEO_CFG (listen 0.0.0.0:6767)"
      else
        # Surgical fix of daemon.listen only; pairings/hostnames untouched.
        ${pkgs.python3}/bin/python3 - "$PASEO_CFG" <<'PYEOF'
      import json, sys
      p = sys.argv[1]
      cfg = json.load(open(p))
      daemon = cfg.setdefault("daemon", {})
      listen = daemon.get("listen", "")
      if listen.startswith("127.0.0.1") or listen.startswith("localhost") or not listen:
          daemon["listen"] = "0.0.0.0:6767"
          json.dump(cfg, open(p, "w"), indent=2)
          print("paseo: rewrote daemon.listen to 0.0.0.0:6767 (was %r)" % listen)
      PYEOF
      fi
    '';

    # Keep port 6767 published to the tailnet via NAT-PMP against the
    # virtual gateway. RunAtLoad + StartInterval re-request well inside the
    # 3600s TTL; requests are idempotent (renewals per RFC 6886).
    launchd.user.agents.paseo-publish = {
      serviceConfig = {
        ProgramArguments = [
          "${pkgs.libnatpmp}/bin/natpmpc"
          "-a" "6767" "6767" "tcp" "3600"
          "-g" "192.168.72.1"
        ];
        RunAtLoad = true;
        StartInterval = 1500; # 25min; TTL is 60min
        StandardOutPath = "/Users/${user}/.paseo/publish.log";
        StandardErrorPath = "/Users/${user}/.paseo/publish.log";
      };
    };
  };
}
