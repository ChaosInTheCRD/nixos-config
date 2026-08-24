{
  description = "Tom's Personal NixOS and Darwin System Flake Configuration";

  inputs =                                                                  # All flake references used to build my NixOS setup. These are dependencies.
    {
      nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";                  # Nix Packages
      nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";                  # Nix Packages
      nixpkgs-wayland.url = "github:nix-community/nixpkgs-wayland";

      home-manager = {                                                      # User Package Management
        url = "github:nix-community/home-manager/master";
        inputs.nixpkgs.follows = "nixpkgs-unstable";
      };

      darwin = {
        url = "github:lnl7/nix-darwin/master";                              # MacOS Package Management
        inputs.nixpkgs.follows = "nixpkgs-unstable";
      };

      hyprland = {
        url = "github:hyprwm/Hyprland";
        inputs.nixpkgs.follows = "nixpkgs-unstable";
      };

      xremap-flake.url = "github:xremap/nix-flake";

      paseo.url = "github:getpaseo/paseo";                                 # Paseo daemon for AI coding agents (LLM sandbox VMs)

      nixpkgs-wayland.inputs.nixpkgs.follows = "nixpkgs";
    };

  outputs = inputs @ { self, xremap-flake, hyprland, nixpkgs, nixpkgs-unstable, home-manager, darwin, ... }:   # Function that tells my flake which to use and what do what to do with the dependencies.
    let                                                                     # Variables that can be used in the config files.
      mkDarwin = import ./lib/mkdarwin.nix;
      mkSys = import ./lib/mksys.nix;
      mkServer = import ./lib/mkserver.nix;
      user = "chaosinthecrd";
      system = "x86_64-linux";
      pkgs  = import nixpkgs {
      inherit system; 
      config = { allowUnfree = true; allowInsecure = true; };
      overlays = [
        (final: prev: {
          nordpass = final.callPackage ./pkgs/nordpass { };
          waterfox = (import ./pkgs/waterfox { pkgs = pkgs; });
          waybar = inputs.nixpkgs-unstable.legacyPackages.${system}.waybar;
          swww = inputs.nixpkgs-unstable.legacyPackages.${system}.swww;
          _1password-gui = inputs.nixpkgs-unstable.legacyPackages.${system}._1password-gui;
          dunst = inputs.nixpkgs-unstable.legacyPackages.${system}.dunst;
          slack = inputs.nixpkgs-unstable.legacyPackages.${system}.slack;
          nwg-look = inputs.nixpkgs-unstable.legacyPackages.${system}.nwg-look;
          cartridges = inputs.nixpkgs-unstable.legacyPackages.${system}.cartridges;
          steam = inputs.nixpkgs-unstable.legacyPackages.${system}.steam;
          lutris = inputs.nixpkgs-unstable.legacyPackages.${system}.lutris;
          looking-glass = inputs.nixpkgs-unstable.legacyPackages.${system}.looking-glass;
          go = inputs.nixpkgs-unstable.legacyPackages.${system}.go;
        })
      ];
      };
    in                                                                      # Use above variables in ...
    {

      nixosConfigurations.desktop = mkSys "desktop" rec {
         inherit home-manager user nixpkgs xremap-flake hyprland system pkgs;
         lib = pkgs.lib;
      };

      nixosConfigurations.server = mkServer "server" rec {
         inherit home-manager user nixpkgs system pkgs;
         lib = pkgs.lib;
      };

      nixosConfigurations.server-arm64 = mkServer "server" rec {
         inherit home-manager user nixpkgs;
         system = "aarch64-linux";
         pkgs = import nixpkgs {
           system = "aarch64-linux";
           config = { allowUnfree = true; allowInsecure = true; };
         };
         lib = pkgs.lib;
      };

      # Standalone home-manager configurations for non-NixOS systems
      # Automatically available for both x86_64-linux and aarch64-linux
      homeConfigurations =
        let
          mkHomeConfig = systemArch: extraModules:
            let
              systemPkgs = import nixpkgs {
                system = systemArch;
                config = { allowUnfree = true; allowInsecure = true; };
              };
            in
            home-manager.lib.homeManagerConfiguration {
              pkgs = systemPkgs;
              extraSpecialArgs = {
                paseoPackage = inputs.paseo.packages.${systemArch}.paseo;
              };
              modules = [
                ./users/default/home-manager-server.nix
                {
                  home = {
                    username = builtins.getEnv "USER";
                    homeDirectory = builtins.getEnv "HOME";
                    stateVersion = "23.05";
                  };
                }
              ] ++ extraModules;
            };
        in
        {
          # Generate configs for all Linux architectures
          "${user}@x86_64-linux" = mkHomeConfig "x86_64-linux" [ ];
          "${user}@aarch64-linux" = mkHomeConfig "aarch64-linux" [ ];

          # Default to current system
          ${user} = mkHomeConfig builtins.currentSystem [ ];

          # LLM sandbox VM profile: server config + paseo daemon + corp git workflow
          # (see LLM-VM.md; username comes from $USER, so works for the ubuntu user)
          "llm@x86_64-linux" = mkHomeConfig "x86_64-linux" [ ./modules/llm-vm.nix ];
          "llm@aarch64-linux" = mkHomeConfig "aarch64-linux" [ ./modules/llm-vm.nix ];
        };

      darwinConfigurations.macbook-m1 = mkDarwin "macbook-m1" rec {
        inherit darwin home-manager user;
        system = "aarch64-darwin";
        pkgs = import nixpkgs { inherit system; };
        lib = pkgs.lib;
      };

      darwinConfigurations.macbook-x86 = mkDarwin "macbook-x86" rec {
        inherit darwin home-manager user;
        system = "x86_64-darwin";
        pkgs = import nixpkgs { inherit system; };
        lib = pkgs.lib;
      };

      # macOS guest under tailvisor: claude/agent work happens here, not on
      # the physical macbook. No WM, minimal casks (machines/
      # macbook-tailvisor-macos.nix sets tailvisor.guest = true).
      # Build: make switch NIXNAME=macbook-tailvisor-macos
      darwinConfigurations.macbook-tailvisor-macos = mkDarwin "macbook-tailvisor-macos" rec {
        inherit darwin home-manager user;
        system = "aarch64-darwin";
        pkgs = import nixpkgs { inherit system; };
        lib = pkgs.lib;
      };

    };
}
