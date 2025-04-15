#
# Git
#

{
  programs = {
    git = {
      enable = true;
      userName = "chaosinthecrd";
      userEmail = "tom@tmlabs.co.uk";
      extraConfig = {
        core = { askpass = "/opt/homebrew/bin/ssh-askpass"; };
        pull = { rebase = "true"; };
        user = { signingkey = "84B6049F3398724F3300230C9A98F924E51C73A8"; };
        commit = { gpgsign = "true"; };
      };
    };
  };
}
