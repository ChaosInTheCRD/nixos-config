{ config, pkgs, user, ... }:
let
  # pymobiledevice3 providing `remote tunneld`.
  # Pinned to the pipx install: (a) nixpkgs has no top-level `pymobiledevice3`,
  # and (b) this is the exact version (10.11.2) the USB RemotePairing record was
  # established with -- referencing it avoids record/version skew. To use a
  # nix-built one instead (accepting possible skew), swap to:
  #   pmd3 = "${pkgs.python3.withPackages (ps: [ ps.pymobiledevice3 ])}/bin/pymobiledevice3";
  pmd3 = "/Users/${user}/Library/Application Support/pipx/venvs/pymobiledevice3/bin/pymobiledevice3";

  # CoreDevice-over-Tailscale bridge script (copied into the nix store).
  bridgeScript = ../scripts/coredevice-tailnet-bridge.sh;
in {

  networking = {
    computerName = "Toms MacBook";             # Host name
    hostName = "toms-macbook";
  };

  fonts.packages = [
    pkgs.nerd-fonts.jetbrains-mono
    pkgs.nerd-fonts.iosevka
  ];

  # Long-lived CoreDevice USB tunnel: `pymobiledevice3 remote tunneld`.
  #
  # Keeps the USB-tethered iPhone's developer services reachable so the
  # tailvisor guest can drive the phone over netd's ULA path (the guest's
  # gateway ULA -> host loopback :49151 discovery API + the CoreDevice utun
  # tunnels). Root daemon, starts at boot, restarts on exit (phone
  # unplug/replug, crash). Default loopback bind + :49151 -- do NOT widen;
  # netd maps exactly this.
  #
  # Runtime prerequisites (device state, NOT managed by nix):
  #   * iPhone on USB, unlocked, Developer Mode ON.
  #   * A RemotePairing record at
  #     /Users/${user}/.pymobiledevice3/remote_<UDID>.plist, established once
  #     over USB (iOS 26 only permits establishing this over USB, not network).
  # HOME points at the user's home below so this root daemon reuses that
  # interactively-established trust instead of trying to pair from /var/root.
  launchd.daemons.pymobiledevice-tunneld.serviceConfig = {
    ProgramArguments = [ pmd3 "remote" "tunneld" ];
    RunAtLoad = true;
    KeepAlive = true;                 # keep it up across phone re-plug / crash
    ProcessType = "Background";
    EnvironmentVariables = {
      HOME = "/Users/${user}";        # reuse the user's USB-established pairing record
      PATH = "/usr/bin:/bin:/usr/sbin:/sbin";
    };
    StandardOutPath = "/var/log/pymobiledevice-tunneld.out.log";
    StandardErrorPath = "/var/log/pymobiledevice-tunneld.err.log";
  };

  # CoreDevice-over-Tailscale bridge: reach the iPhone over Tailscale when it is
  # NOT on the local network (roaming / cellular). Spoofs the phone's
  # _remotepairing record onto en0 and relays :49152 + the tunnel range to the
  # phone's long-lived tailnet IP, so Apple's `devicectl` on THIS host tunnels
  # through over Tailscale (the only path that works remotely -- pymobiledevice3
  # tunneld is USB-only and iOS 26 blocks third-party RemotePairing over the net).
  #
  # ALWAYS-ON but SELF-GATING (see the script): it only spoofs when the phone is
  # actually remote. When the phone is home on the LAN it stands down, because
  # spoofing then collides with the phone's real record ("Name in use") and would
  # shadow it -- the original bug. A watchdog also stands down if the phone comes
  # back to the LAN. So RunAtLoad + KeepAlive are safe here.
  #   logs:  /var/log/coredevice-tailnet-bridge.{out,err}.log
  #   NOTE:  while active it runs ~600 socat procs (49152 + the 55000-55300 range
  #          x TCP/UDP). Narrow PORT_LO/PORT_HI below if you want less overhead
  #          (the CoreDevice tunnel itself rode TCP/49152 in testing).
  #
  # Reaches the phone for the HOST's `devicectl` only; does NOT extend the
  # guest-via-netd path to a remote phone (guest can't hold network trust).
  #
  # Device values are the phone's long-lived tailnet identity; en0's DHCP IP is
  # auto-detected in the script so a LAN IP change needs no rebuild. If the phone
  # is re-paired/reset and its _remotepairing instance or authTag change, update
  # INSTANCE/AUTHTAG here.
  launchd.daemons.coredevice-tailnet-bridge.serviceConfig = {
    ProgramArguments = [ "/bin/bash" "${bridgeScript}" ];
    RunAtLoad = true;
    KeepAlive = true;                 # self-gating script makes always-on safe
    ThrottleInterval = 20;            # don't hot-loop while the phone is home
    ProcessType = "Background";
    EnvironmentVariables = {
      IPHONE_IP = "100.110.252.17";                          # phone tailnet IPv4 (long-lived)
      INSTANCE  = "74080433-2AB8-49B0-9091-BC236941E444";    # phone _remotepairing instance UUID
      AUTHTAG   = "qIVJ7YLb";                                # phone _remotepairing authTag
      HOST      = "Toms-iPhone.local";
      PATH = "${pkgs.socat}/bin:/usr/bin:/bin:/usr/sbin:/sbin";
    };
    StandardOutPath = "/var/log/coredevice-tailnet-bridge.out.log";
    StandardErrorPath = "/var/log/coredevice-tailnet-bridge.err.log";
  };

}
