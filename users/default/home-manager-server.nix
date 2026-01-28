# Shell-only home-manager configuration for servers
# No GUI applications, only shell tools and CLI utilities
{ lib, pkgs, ... }:

{
  imports = [
    ../../modules/shell/git-server.nix
    ../../modules/shell/zsh-server.nix
    ../../modules/shell/ssh.nix
    ../../modules/shell/direnv-hm.nix
    ../../modules/editors/nvim/nvim-server.nix
    ../../pkgs/core.nix
    ../../pkgs/dev.nix
    ../../pkgs/kube.nix
    # Platform-specific packages omitted for server config
    # Add them manually if needed
  ];

  # Auto-switch to zsh from bash (for systems where bash is the login shell)
  programs.bash = {
    enable = true;
    initExtra = ''
      # Source Nix daemon if installed
      if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
        . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
      fi

      # Add Nix to PATH
      export PATH="/nix/var/nix/profiles/default/bin:$PATH"

      # Add home-manager path
      export PATH="$HOME/.local/state/nix/profiles/home-manager/home-path/bin:$PATH"

      # Lima-specific PATH (preserve if on Lima)
      PATH="$PATH:/usr/sbin:/sbin"
      export PATH

      # Auto-switch to zsh if not already in zsh
      if [ -z "$ZSH_VERSION" ] && command -v zsh >/dev/null 2>&1; then
        exec zsh
      fi
    '';
  };

  home = {
    stateVersion = "23.05";
    sessionVariables = {
      TERM = "xterm-256color";
    };
  };
}
