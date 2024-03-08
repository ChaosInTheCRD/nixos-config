# This function creates a nix-darwin system.
name: { darwin, pkgs, lib, home-manager, system, user }:

darwin.lib.darwinSystem {
  inherit system;

  specialArgs = { inherit system; inherit user; };
  modules = [

    ../machines/${name}.nix
    ../machines/shared.nix
    ../darwin/configuration.nix

    { 
      documentation.enable = false; 
      nix.distributedBuilds = true;
      nix.buildMachines = [{
        hostName = "ssh://builder@localhost";
        system = "aarch64-linux";
        maxJobs = 4;
        supportedFeatures = [ "kvm" "benchmark" "big-parallel" ];
      }];
    }

    home-manager.darwinModules.home-manager {
      home-manager.useUserPackages = true;
      home-manager.useGlobalPkgs = true;
      home-manager.users.${user} = import ../users/${user}/home-manager.nix {
          inherit lib pkgs;
      };
    }

  ];
}
