{ lib, pkgs, ... }:

# iOS deploy pipeline. Imported for all darwin machines: the physical HOST runs
# `tunneld` and the tailvisor GUEST drives the phone, so both need pymobiledevice3.
# The `ios-deploy` command is the guest's build→install→relaunch driver (the host
# just needs the pymobiledevice3 the activation ensures, for tunneld).
#
# Architecture (the "guest drives iPhone" setup): the physical HOST runs
# `pymobiledevice3 remote tunneld` — it holds the phone's USB pairing trust and
# the live tunnel, and routes that tunnel's IPv6 to this guest (RA + RFC 4191).
# The guest never pairs or builds a tunnel itself; it only reads the phone's RSD
# endpoint from the host's tunneld and drives it. iOS 26 forbids a guest from
# pairing over the network, so the host stays the trust anchor by necessity.
#
# pymobiledevice3 + pipx come from Homebrew, NOT nixpkgs: the guest needs a
# recent pymobiledevice3 (>=10, for `apps install --rsd` + `developer
# core-device launch-application`), nixpkgs doesn't build it for aarch64-darwin
# (Linux-only tun dep the guest never uses), and nixpkgs' `pipx` also fails its
# test suite on darwin here. `pipx` is declared in the guest Homebrew brews
# (darwin/configuration.nix); this module ensures pymobiledevice3 is installed
# into it and provides the `ios-deploy` command.

let
  ios-deploy = pkgs.writeShellApplication {
    name = "ios-deploy";
    runtimeInputs = [ pkgs.curl pkgs.python3 ];
    text = ''
      # Build + sign with the SYSTEM Xcode, find the phone's RSD via the host's
      # tunneld, install over the tunnel, then force-quit + relaunch (Xcode-style).
      PROJECT="''${IOS_PROJECT:-$HOME/Git/crate/ios/Shared Noise}"
      SCHEME="''${IOS_SCHEME:-Shared Noise}"
      BUNDLE_ID="''${IOS_BUNDLE_ID:-sharednoise.Shared-Noise}"
      TUNNELD_URL="''${TUNNELD_URL:-http://[fd74:6169:6c76::1]:49151/}"
      PIPX="$(command -v pipx || echo /opt/homebrew/bin/pipx)"
      PMD="$("$PIPX" environment --value PIPX_LOCAL_VENVS)/pymobiledevice3/bin/pymobiledevice3"

      echo "==> Building + signing…"
      cd "$PROJECT" || exit 1
      xcodebuild -project "$SCHEME.xcodeproj" -scheme "$SCHEME" \
        -destination 'generic/platform=iOS' -configuration Debug -allowProvisioningUpdates build \
        >/tmp/ios-deploy-build.log 2>&1 || { echo "BUILD FAILED:"; tail -25 /tmp/ios-deploy-build.log; exit 1; }
      APP="$(find "$HOME/Library/Developer/Xcode/DerivedData" -name "$SCHEME.app" -path '*Debug-iphoneos*' | head -1)"
      echo "    built: $APP"

      echo "==> Locating the phone's RSD via tunneld…"
      RSD="$(curl -s --max-time 8 "$TUNNELD_URL" | python3 -c \
        'import sys,json; t=[x for v in json.load(sys.stdin).values() for x in v]; print(t[0]["tunnel-address"], t[0]["tunnel-port"]) if t else None')"
      [ -n "$RSD" ] || { echo "No active tunnel — is tunneld running on the host with the phone plugged in?"; exit 1; }
      ADDR="''${RSD%% *}"; PORT="''${RSD##* }"
      echo "    RSD: $ADDR $PORT"

      echo "==> Installing over the tunnel…"
      "$PMD" apps install --rsd "$ADDR" "$PORT" "$APP"

      echo "==> Relaunching on device…"
      "$PMD" developer core-device launch-application "$BUNDLE_ID" "" --rsd "$ADDR" "$PORT" >/dev/null
      echo "==> Done — build installed and relaunched on the phone."
    '';
  };
in
{
  home.packages = [ ios-deploy ];

  # Ensure pymobiledevice3 is installed into the Homebrew-managed pipx. Pinned to
  # 10.11.2 to match the version the host's USB RemotePairing record was
  # established with — the host's `remote tunneld` daemon (machines/macbook-m1.nix)
  # runs this same pipx binary, and version skew against the pairing record breaks
  # the tunnel. Non-fatal so an offline switch doesn't break activation; only
  # installs when missing (won't clobber an existing/newer pin).
  home.activation.pymobiledevice3 = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    PIPX=/opt/homebrew/bin/pipx
    if [ -x "$PIPX" ] && ! "$PIPX" list 2>/dev/null | grep -q pymobiledevice3; then
      "$PIPX" install 'pymobiledevice3==10.11.2' || echo "ios-deploy: pipx install pymobiledevice3 failed (install manually)"
    fi
  '';
}
