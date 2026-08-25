{ config, pkgs, user, ... }: {

  # macOS guest under tailvisor (Virtualization.framework, tsnet networking).
  # Purpose: run claude and agent tooling OFF the physical macbook - the
  # host keeps no claude install. Window management runs in here too, on a
  # cmd+ctrl prefix so it doesn't collide with the host's alt-based skhd
  # (see darwin/guest-wm.nix). SIP is disabled in this guest so yabai's
  # scripting addition can load — that's what makes space switching instant.
  tailvisor.guest = true;

  networking = {
    computerName = "tailvisor macos";
    hostName = "macbook-tailvisor-macos";
  };

  fonts.packages = [
    pkgs.nerd-fonts.jetbrains-mono
    pkgs.nerd-fonts.iosevka
  ];

}
