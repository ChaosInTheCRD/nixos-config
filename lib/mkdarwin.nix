# This function creates a nix-darwin system.
name: { darwin, pkgs, lib, home-manager, system, user }:

darwin.lib.darwinSystem {
  inherit system;

  specialArgs = { inherit system; inherit user; };
  modules = [
    ../machines/${name}.nix
    ../machines/shared.nix
    ../darwin/configuration.nix

    home-manager.darwinModules.home-manager {
      home-manager.useUserPackages = true;
      home-manager.useGlobalPkgs = true;
      home-manager.users.${user} = import ../users/${user}/home-manager.nix {
          inherit lib pkgs;
      };
    }

  ];
}
