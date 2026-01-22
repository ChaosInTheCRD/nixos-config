# Generic hardware configuration for servers
# This is a minimal configuration that should work on most x86_64 Linux systems
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  boot.initrd.availableKernelModules = [ "ahci" "xhci_pci" "virtio_pci" "sd_mod" "sr_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  # Use DHCP on all interfaces by default
  networking.useDHCP = lib.mkDefault true;

  # Will be overridden by the specific configuration
  # nixpkgs.hostPlatform is set by the flake based on the system parameter
}
