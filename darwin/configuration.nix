#
#  Specific system configuration settings for MacBook
#
#  flake.nix
#   └─ ./darwin
#       ├─ ./default.nix
#       └─ ./configuration.nix *
#

{ config, pkgs, user, system, ... }:
{

  users.users."${user}" = {               # macOS user
    home = "/Users/${user}";
    shell = pkgs.zsh;                     # Default shell
  };
  environment.systemPackages = [ 
    (import (fetchTarball https://install.devenv.sh/latest)).default
  ];

  # Moved all the global package setup to pkgs/default.nix

  nixpkgs.config.allowBroken = true;

  homebrew = {                            # Declare Homebrew using Nix-Darwin
    enable = true;
    onActivation = {
      autoUpdate = false;                 # Auto update packages
      upgrade = false;
      cleanup = "zap";                    # Uninstall not listed packages and casks
    };
    taps = [
      "FelixKratz/formulae"
      # "homebrew/cask-drivers"
      "koekeishiya/formulae"
      "theseal/ssh-askpass"
    ];
    brews = [
      "FelixKratz/formulae/sketchybar"
      "FelixKratz/formulae/borders"
      "koekeishiya/formulae/skhd"
      "koekeishiya/formulae/yabai"
      "theseal/ssh-askpass/ssh-askpass"
      "ddcctl"
      "ykman"
      "gpg"
      "openssh"
      "pinentry"
      "blueutil"
      "node"
      "wifi-password"
      "switchaudio-osx"
      "oras"
    ];
    casks = [
      "tailscale"
      "firefox"
      "akiflow"
      "beeper"
      "launchcontrol"
      "orbstack"
      "kitty"
      "gpg-suite"
      "google-chrome"
      "now-tv-player"
      "plex"
      "steam"
      "ghostty"
      "alacritty"
      "slack"
      "spotify"
      "notion"
      "raycast"
      "transmission"
      "via"
      "vlc"
      "visual-studio-code"
      "tidal"
      "insomnia"
      "nordvpn"
      "nordpass"
      "iterm2"
      # installs new version that I do not like
      # "readdle-spark"
      "element"
      "zoom"
      "microsoft-teams"
      "sf-symbols"
    ];
  };

  

  system = {
    defaults = {
      NSGlobalDomain = {                  # Global macOS system settings
        KeyRepeat = 1;
        NSAutomaticCapitalizationEnabled = false;
        NSAutomaticSpellingCorrectionEnabled = false;
        NSAutomaticWindowAnimationsEnabled = false;
        _HIHideMenuBar = true;
        "com.apple.swipescrolldirection" = false;
        AppleTemperatureUnit = "Celsius";

      };
      dock = {               # Dock settings
        autohide = true;
        autohide-delay = 0.0;
        autohide-time-modifier = 0.0;
        dashboard-in-overlay = true;
        expose-animation-duration = 0.0;
        launchanim = false;
        orientation = "left";
        showhidden = true;
        mru-spaces = false;
        show-recents = false;
        static-only = true;
        tilesize = 40;
      };
      finder = {                          # Finder settings
        QuitMenuItem = true;              # I believe this probably will need to be true if using spacebar
        AppleShowAllExtensions = true; 
      };  
      trackpad = {                        # Trackpad settings
        Clicking = true;
        TrackpadRightClick = true;
      };
      SoftwareUpdate = {
        AutomaticallyInstallMacOSUpdates = true;
      };
    };
    activationScripts.postActivation.text = ''sudo chsh -s ${pkgs.zsh}/bin/zsh''; # Since it's not possible to declare default shell, run this command after build
    stateVersion = 5;
  };
}
