{ pkgs, ... }:
with pkgs;

{

  home = {
    packages = with pkgs; [
      # Terminal
      yq coreutils-full fzf ripgrep bat colordiff htop tree wget diceware
      keychain watch jq starship git gcc gnumake gawk tmate neofetch
      glow step-ca asciinema asciinema-agg objconv
    ];
  };
  
}
