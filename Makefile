# Mark targets that aren't files
.PHONY: install update switch bootstrap build-server home-manager setup-home-manager bootstrap-llm help

# LLM sandbox VM (corp workstation) for `make bootstrap-llm`
# Default LLM VM comes from the private env file (see bin/_llm-lib.sh);
# override with VM=<name> or set it in ~/.config/llm-vm/env
-include $(HOME)/.config/llm-vm/env
VM ?= $(LLM_VM)

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

home-manager:
	@echo "Activating home-manager configuration (auto-detecting architecture)..."
	NIX_CONFIG="$(NIX_CONFIG)" nix run home-manager/master -- switch --flake ".#$(USER)" --impure

setup-home-manager:
	@echo "Setting up home-manager with automatic backup of existing shell configs..."
	@echo "Ensuring Nix is in PATH..."
	@export PATH="/nix/var/nix/profiles/default/bin:$$PATH"; \
	echo "Detecting architecture..."; \
	ARCH=$$(uname -m); \
	if [ "$$ARCH" = "x86_64" ]; then \
		SYSTEM="x86_64-linux"; \
	elif [ "$$ARCH" = "aarch64" ] || [ "$$ARCH" = "arm64" ]; then \
		SYSTEM="aarch64-linux"; \
	else \
		echo "Unsupported architecture: $$ARCH"; \
		exit 1; \
	fi; \
	echo "Detected system: $$SYSTEM"; \
	echo "Applying home-manager configuration..."; \
	echo "Note: Existing files will be backed up with .backup extension"; \
	NIX_CONFIG="$(NIX_CONFIG)" nix run home-manager/master -- switch -b backup --flake ".#$(USER)@$$SYSTEM" --impure
	@echo ""
	@echo "Setup complete! Please log out and log back in for changes to take effect."
	@echo "Your old config files have been backed up with .backup extension."

bootstrap: install update switch

bootstrap-llm:
	@echo "Bootstrapping LLM sandbox VM: $(VM)"
	@if [ -d $(HOME)/Git/chaosinthecrd-private-dots/vm-files ]; then \
		echo "Copying private VM files (testctl, agent context)"; \
		ssh $(USER)@$(VM) 'mkdir -p ~/.config/testctl'; \
		scp $(HOME)/Git/chaosinthecrd-private-dots/vm-files/testctl-start.sh $(USER)@$(VM):.config/testctl/start.sh; \
		ssh $(USER)@$(VM) 'chmod +x ~/.config/testctl/start.sh'; \
		scp $(HOME)/Git/chaosinthecrd-private-dots/vm-files/claude_context.md $(USER)@$(VM):.claude_context.md.new; \
		ssh $(USER)@$(VM) '[ -f ~/.claude_context.md ] || mv ~/.claude_context.md.new ~/.claude_context.md; rm -f ~/.claude_context.md.new'; \
		scp $(HOME)/Git/chaosinthecrd-private-dots/vm-files/claude_k8s_style.md $(USER)@$(VM):.claude_k8s_style.md.new; \
		ssh $(USER)@$(VM) '[ -f ~/.claude_k8s_style.md ] || mv ~/.claude_k8s_style.md.new ~/.claude_k8s_style.md; rm -f ~/.claude_k8s_style.md.new'; \
		for p in $(HOME)/Git/chaosinthecrd-private-dots/vm-files/claude_reviewer_*.md; do \
			f=$$(basename $$p); \
			scp $$p $(USER)@$(VM):.$$f.new; \
			ssh $(USER)@$(VM) "[ -f ~/.$$f ] || mv ~/.$$f.new ~/.$$f; rm -f ~/.$$f.new"; \
		done; \
	fi
	ssh $(USER)@$(VM) 'bash -s' < $(MAKEFILE_DIR)/scripts/bootstrap-llm-vm.sh

update-llm:
	VM=$(VM) $(MAKEFILE_DIR)/scripts/update-llm-vm.sh

help:
	@echo "Available targets:"
	@echo "  install              - Install Nix package manager"
	@echo "  update               - Run 'nix flake update'"
	@echo "  switch               - Apply the system configuration (Darwin or NixOS)"
	@echo "  build-server         - Build server configuration (shell only, no GUI)"
	@echo "  home-manager         - Apply home-manager config (auto-detects architecture)"
	@echo "  setup-home-manager   - Backup existing shell configs and apply home-manager"
	@echo "  bootstrap            - Run install, update, and switch in sequence"
	@echo "  bootstrap-llm        - Bootstrap an LLM sandbox VM over ssh (VM=<name>, see LLM-VM.md)"
	@echo "  update-llm           - Bump flake.lock here, then update + switch the LLM VM"
	@echo "  help                 - Show this help message"
	@echo ""
	@echo "For any Linux server/VM (Debian, Ubuntu, Lima, etc.):"
	@echo "  1. Clone this repo to ~/.config/nixos-config"
	@echo "  2. Run: make install"
	@echo "  3. Run: make setup-home-manager (backs up existing configs)"
	@echo "  4. Log out and log back in"
	@echo ""
	@echo "Architecture detection is automatic (x86_64 or aarch64)."
