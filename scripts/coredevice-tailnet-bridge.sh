#!/bin/bash
# CoreDevice-over-Tailscale bridge (host side), self-gating.
#
# Spoofs the phone's Bonjour `_remotepairing` record onto en0 and byte-relays
# the front door (49152) + the tunnel port range to the phone's TAILNET IP, so
# Apple's `devicectl` on this host can reach the phone over Tailscale when the
# phone is NOT on the local network (roaming / cellular-only).
#
# This is the ONLY way to reach a remote phone: pymobiledevice3 `tunneld` is
# USB-only, and iOS 26 refuses third-party RemotePairing over the network. This
# path instead lets Apple's own devicectl (which holds the non-exportable
# keychain trust) tunnel through, believing the phone is on the local network.
#
# SELF-GATING so it is safe to run always-on (RunAtLoad + KeepAlive):
#   * On start it checks whether the phone's REAL _remotepairing record is on the
#     local net. If so the phone is HOME -> it stands down (exits; launchd
#     re-checks). Spoofing then would collide ("Name in use") and shadow the real
#     phone -- the original bug.
#   * While active it watches for a name conflict (phone came back to the LAN) or
#     an en0 IP change, and tears down so launchd re-checks from the gate.
#
# Config via env (the launchd daemon sets these). EN0_IP is auto-detected:
#   IPHONE_IPS  space-separated phone tailnet IPv4s in PRIORITY order; the first
#               one that answers on :49152 is used (e.g. personal tailnet first,
#               corp tailnet as fallback). Only the tailnet the host is currently
#               logged into is routable, so probing lets one config work on either.
#   INSTANCE   phone's _remotepairing instance UUID
#   AUTHTAG    phone's _remotepairing authTag
#   HOST       phone's .local hostname             (e.g. Toms-iPhone.local)
#   PORT_LO/PORT_HI  tunnel relay range            (default 55000-55300)
#   RECHECK    seconds between active re-checks     (default 30)
set -uo pipefail

IPHONE_IPS="${IPHONE_IPS:?set IPHONE_IPS (space-separated phone tailnet IPv4s, priority order)}"
INSTANCE="${INSTANCE:?set INSTANCE (phone _remotepairing UUID)}"
AUTHTAG="${AUTHTAG:?set AUTHTAG}"
HOST="${HOST:-Toms-iPhone.local}"
PORT_LO="${PORT_LO:-55000}"
PORT_HI="${PORT_HI:-55300}"
RECHECK="${RECHECK:-30}"
SPOOF_LOG="/tmp/coredevice-bridge-spoof.log"

cleanup() { kill $(jobs -p) 2>/dev/null; }
trap cleanup EXIT INT TERM

# Is the phone's REAL _remotepairing record on the local net right now?
# Call this ONLY before we start our own spoof, else we would match ourselves.
phone_is_local() {
  timeout 4 dns-sd -B _remotepairing._tcp local. 2>/dev/null \
    | grep -i "Add" | grep -q "$INSTANCE"
}

# TCP-reachability probe for the phone's front door (:49152) on a candidate IP.
reachable() { nc -z -G 3 -w 3 "$1" 49152 >/dev/null 2>&1; }

# First candidate that answers on :49152, in priority order. Only the tailnet the
# host is currently on is routable, so this picks personal-then-corp correctly.
pick_target() {
  for ip in $IPHONE_IPS; do
    reachable "$ip" && { echo "$ip"; return 0; }
  done
  return 1
}

# GATE: never spoof while the phone is home (collision + shadows real record).
if phone_is_local; then
  echo "$(date '+%H:%M:%S') phone is on the local network -- bridge stands down"
  sleep 20            # avoid a tight KeepAlive restart loop
  exit 0
fi

EN0_IP="$(ipconfig getifaddr en0 2>/dev/null || true)"
[ -n "$EN0_IP" ] || { echo "en0 has no IPv4 -- host not on a network"; sleep 20; exit 1; }

# Pick the reachable tailnet IP (personal first, corp fallback). If none answer,
# the phone is remote but unreachable on any tailnet (offline, or host on neither
# tailnet) -- stand down so we never shadow it with a dead relay; launchd re-checks.
TARGET="$(pick_target || true)"
[ -n "$TARGET" ] || { echo "$(date '+%H:%M:%S') phone remote but no tailnet IP answers on :49152 -- standing down"; sleep 20; exit 0; }

ulimit -n 8192 2>/dev/null || true
echo "$(date '+%H:%M:%S') phone remote -- spoofing $INSTANCE on en0 $EN0_IP -> $TARGET"

dns-sd -P "$INSTANCE" _remotepairing._tcp local 49152 "$HOST" "$EN0_IP" \
  identifier="$INSTANCE" authTag="$AUTHTAG" ver=24 minVer=8 flags=0 \
  > "$SPOOF_LOG" 2>&1 &

socat TCP-LISTEN:49152,bind=$EN0_IP,reuseaddr,fork TCP:$TARGET:49152 &
socat UDP-LISTEN:49152,bind=$EN0_IP,reuseaddr,fork UDP:$TARGET:49152 &
for port in $(seq "$PORT_LO" "$PORT_HI"); do
  socat TCP-LISTEN:$port,bind=$EN0_IP,reuseaddr,fork TCP:$TARGET:$port &
  socat UDP-LISTEN:$port,bind=$EN0_IP,reuseaddr,fork UDP:$TARGET:$port &
done

# WATCHDOG: stand down if the phone returns to the LAN (spoof reports a name
# conflict) or en0's address changes; launchd re-checks from the gate.
while true; do
  sleep "$RECHECK"
  if grep -qi "name in use\|conflict" "$SPOOF_LOG"; then
    echo "$(date '+%H:%M:%S') name conflict -- phone returned to LAN; standing down"
    exit 0
  fi
  if [ "$(ipconfig getifaddr en0 2>/dev/null || true)" != "$EN0_IP" ]; then
    echo "$(date '+%H:%M:%S') en0 IP changed; restarting to rebind"
    exit 0
  fi
  if ! reachable "$TARGET"; then
    echo "$(date '+%H:%M:%S') target $TARGET stopped answering on :49152; restarting to re-pick"
    exit 0
  fi
done
