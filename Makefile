# Mark targets that aren't files
.PHONY: install update switch bootstrap help

# Get the path to this Makefile and directory
MAKEFILE_DIR := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))

# The name of the nixosConfiguration in the flake
NIXNAME ?= macbook-m1

# Nix installation script
NIX_INSTALL_URL := https://nixos.org/nix/install
NIX_INSTALL_SCRIPT := install-nix.sh

# Detect the operating system
UNAME := $(shell uname)

install:
	@echo "Installing Nix..."
	@curl -L $(NIX_INSTALL_URL) -o $(NIX_INSTALL_SCRIPT)
	@chmod +x $(NIX_INSTALL_SCRIPT)
	@sh $(NIX_INSTALL_SCRIPT)
	@rm -f $(NIX_INSTALL_SCRIPT)
	@echo "Nix installation completed. You may need to restart your shell."

update:
	@echo "Updating flake..."
	nix flake update

switch:
ifeq ($(UNAME), Darwin)
	@echo "Building and switching Darwin configuration: $(NIXNAME)"
	nix build ".#darwinConfigurations.${NIXNAME}.system" --impure
	./result/sw/bin/darwin-rebuild switch --flake "$$(pwd)#${NIXNAME}" --impure
else
	@echo "Building and switching NixOS configuration: $(NIXNAME)"
	sudo NIXPKGS_ALLOW_UNSUPPORTED_SYSTEM=1 nixos-rebuild switch --flake ".#${NIXNAME}" --impure
endif

bootstrap: install update switch

help:
	@echo "Available targets:"
	@echo "  install    - Install Nix package manager"
	@echo "  update     - Run 'nix flake update'"
	@echo "  switch     - Apply the system configuration (Darwin or NixOS)"
	@echo "  bootstrap  - Run install, update, and switch in sequence"
	@echo "  help       - Show this help message"
