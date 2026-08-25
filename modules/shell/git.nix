#
# Git
#
# Shared by the host and the tailvisor guest. The host signs commits with the
# YubiKey-backed GPG key; the guest has no YubiKey, so it signs with a software
# SSH key instead (~/.ssh/id_ed25519). osConfig is the nix-darwin system config
# — tailvisor.guest marks the VM (only darwin imports this module, so osConfig
# is always present here).
#

{ osConfig, pkgs, ... }:

let
  isGuest = osConfig.tailvisor.guest or false;
in
{
  programs.git = {
    enable = true;
    userName = "chaosinthecrd";
    userEmail = "tom@tmlabs.co.uk";
    extraConfig = {
      core = { askpass = "/opt/homebrew/bin/ssh-askpass"; excludesFile = "~/.config/global-gitignore"; };
      pull = { rebase = "true"; };
      commit = { gpgsign = "true"; };
    } // (if isGuest then {
      # No YubiKey in the VM: sign with a software SSH key. Register the .pub
      # on GitHub as a signing key to get the Verified badge.
      gpg = { format = "ssh"; };
      user = { signingkey = "~/.ssh/id_ed25519.pub"; };
      # Push over HTTPS via the gh token instead of the ssh-askpass GUI (the
      # `gh auth setup-git` equivalent, done declaratively since ~/.config/git
      # is read-only under home-manager). gh must be signed in.
      credential."https://github.com".helper = "!${pkgs.gh}/bin/gh auth git-credential";
    } else {
      gpg = { format = "openpgp"; };
      user = { signingkey = "84B6049F3398724F3300230C9A98F924E51C73A8"; };
    });
  };
}
