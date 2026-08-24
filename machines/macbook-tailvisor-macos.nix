{ config, pkgs, user, ... }: {

  # macOS guest under tailvisor (Virtualization.framework, tsnet networking).
  # Purpose: run claude and agent tooling OFF the physical macbook - the
  # host keeps no claude install. No window management in here: yabai's
  # scripting addition wants SIP fiddling and skhd's event tap fights the
  # host's (the host blacklists tailvisor in its own skhd for the same
  # reason). Keys pass through to guest apps untouched.
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
