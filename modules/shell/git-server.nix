# Git config for servers without GUI dependencies
{
  programs = {
    git = {
      enable = true;
      userName = "chaosinthecrd";
      userEmail = "tom@tmlabs.co.uk";
      extraConfig = {
        core = { excludesFile = "~/.config/global-gitignore"; };
        pull = { rebase = "true"; };
        # Remove signing config for servers - can be added manually if needed
        # user = { signingkey = "84B6049F3398724F3300230C9A98F924E51C73A8"; };
        # commit = { gpgsign = "true"; };
      };
    };
  };
}
