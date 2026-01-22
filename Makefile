# Mark targets that aren't files
.PHONY: install update switch bootstrap build-server help

# Get the path to this Makefile and directory
MAKEFILE_DIR := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))

# Detect the operating system
UNAME := $(shell uname)

# The name of the nixosConfiguration in the flake
# Default to 'server' for Linux, 'macbook-m1' for Darwin
ifeq ($(UNAME), Linux)
	NIXNAME ?= server
else
	NIXNAME ?= macbook-m1
endif

# Nix installation script
NIX_INSTALL_URL := https://nixos.org/nix/install
NIX_INSTALL_SCRIPT := install-nix.sh

NIX_CONFIG := experimental-features = nix-command flakes

install-brew:
	@echo "Installing Homebrew..."
	@/bin/bash -c "$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

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
	NIX_CONFIG="$(NIX_CONFIG)" nix build ".#darwinConfigurations.${NIXNAME}.system" --impure
	./result/sw/bin/darwin-rebuild switch --flake "$$(pwd)#${NIXNAME}" --impure
else
	@echo "Building and switching NixOS configuration: $(NIXNAME)"
	sudo NIX_CONFIG="$(NIX_CONFIG)" NIXPKGS_ALLOW_UNSUPPORTED_SYSTEM=1 nixos-rebuild switch --flake ".#${NIXNAME}" --impure
endif

build-server:
	@echo "Building server configuration (shell tools only, no GUI)..."
	NIX_CONFIG="$(NIX_CONFIG)" nix build ".#nixosConfigurations.server.config.system.build.toplevel" --impure

bootstrap: install update switch

help:
	@echo "Available targets:"
	@echo "  install       - Install Nix package manager"
	@echo "  update        - Run 'nix flake update'"
	@echo "  switch        - Apply the system configuration (Darwin or NixOS)"
	@echo "  build-server  - Build server configuration (shell only, no GUI)"
	@echo "  bootstrap     - Run install, update, and switch in sequence"
	@echo "  help          - Show this help message"
	@echo ""
	@echo "On Linux servers, 'make switch' will default to the server configuration."
	@echo "You can override with: make switch NIXNAME=desktop"
