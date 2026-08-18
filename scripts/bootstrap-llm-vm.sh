#!/usr/bin/env bash
# Bootstrap an LLM sandbox VM with:
#   - Nix + this repo's home-manager `llm` profile (paseo daemon, codex/opencode
#     via Aperture, expose helper, corp git workflow)
#   - lingering user session so services survive reboot
#   - corp checkout via rogitproxy + maintner gh/mn tools
#
# Run from the Mac as the user you work as on the VM:
#   make bootstrap-llm            (or VM=<name> make bootstrap-llm)
# which does: ssh $USER@<vm> 'bash -s' < scripts/bootstrap-llm-vm.sh
#
# Idempotent: safe to re-run to pick up config changes. Existing runtime
# paseo state (~/.paseo) is never touched.

set -euo pipefail

REPO_URL="https://github.com/chaosinthecrd/nixos-config.git"
REPO_DIR="$HOME/Git/nixos-config"
CORP_DIR="$HOME/Git/corp"

log() { echo "==> $*"; }

# --- Nix ---------------------------------------------------------------
if ! command -v nix &>/dev/null && [ ! -e /nix/var/nix/profiles/default/bin/nix ]; then
    log "Installing Nix (multi-user)"
    sh <(curl -fsSL https://nixos.org/nix/install) --daemon --yes
else
    log "Nix already installed"
fi

if [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
    # shellcheck disable=SC1091
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi
export PATH="/nix/var/nix/profiles/default/bin:$HOME/.local/state/nix/profiles/home-manager/home-path/bin:$PATH"

mkdir -p ~/.config/nix
grep -q 'experimental-features' ~/.config/nix/nix.conf 2>/dev/null || \
    echo 'experimental-features = nix-command flakes' >> ~/.config/nix/nix.conf

# --- systemd user session ----------------------------------------------
# User services (paseo, expose@) must survive logout/reboot.
sudo loginctl enable-linger "$USER"
export XDG_RUNTIME_DIR="/run/user/$(id -u)"

# --- docker (for kind clusters / verification workflows) -----------------
# Note: nix's dev.nix puts a dockerd binary on PATH, but the *daemon* needs
# the distro package (systemd unit + docker group), so check for the unit.
if ! systemctl list-unit-files docker.service --no-legend 2>/dev/null | grep -q docker; then
    log "Installing docker"
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y docker.io
fi
sudo systemctl enable --now docker
if ! id -nG "$USER" | grep -qw docker; then
    sudo usermod -aG docker "$USER"
    log "Added $USER to docker group (takes effect on next login)"
fi
# Group membership only lands in NEW login sessions, and this VM runs
# lingering user sessions that never re-login — so also grant socket access
# via ACL, reapplied by a drop-in every time docker (re)starts.
command -v setfacl >/dev/null || sudo DEBIAN_FRONTEND=noninteractive apt-get install -y acl
sudo mkdir -p /etc/systemd/system/docker.service.d
printf '[Service]\nExecStartPost=/usr/bin/setfacl -m u:%s:rw /var/run/docker.sock\n' "$USER" \
    | sudo tee /etc/systemd/system/docker.service.d/socket-acl.conf >/dev/null
sudo systemctl daemon-reload
sudo setfacl -m "u:$USER:rw" /var/run/docker.sock
log "Docker socket ACL granted to $USER (survives docker restarts via drop-in)"

# --- nixos-config repo ---------------------------------------------------
# Lives at ~/Git/nixos-config to mirror the Mac's layout, so `aif` (which
# derives the remote path from the repo's $HOME-relative path) works on it.
if [ ! -d "$REPO_DIR" ]; then
    log "Cloning nixos-config to $REPO_DIR"
    mkdir -p "$HOME/Git"
    git clone "$REPO_URL" "$REPO_DIR"
else
    log "Updating nixos-config"
    git -C "$REPO_DIR" pull --ff-only || log "WARN: nixos-config pull skipped (local changes?)"
fi

# --- home-manager (llm profile) ------------------------------------------
case "$(uname -m)" in
    x86_64)          SYSTEM="x86_64-linux" ;;
    aarch64 | arm64) SYSTEM="aarch64-linux" ;;
    *) echo "Unsupported architecture: $(uname -m)"; exit 1 ;;
esac

log "Applying home-manager profile llm@$SYSTEM (existing dotfiles backed up as .backup)"
nix run home-manager/master -- switch -b backup --flake "$REPO_DIR#llm@$SYSTEM" --impure

# --- corp checkout via rogitproxy ----------------------------------------
if [ ! -d "$CORP_DIR" ]; then
    log "Cloning tailscale/corp via rogitproxy (blobless)"
    git clone --filter=blob:none git://rogitproxy/tailscale/corp "$CORP_DIR"
else
    log "corp checkout already present"
fi

# --- maintner tools --------------------------------------------------------
# Read-only gh replacement + mn CLI, backed by http://maintner.corp.ts.net.
# Installed into ~/.local/bin, which precedes nix profiles in PATH so this
# gh shadows any nix-installed one (real gh can't auth on the sandbox anyway).
log "Building maintner gh + mn (first run compiles the hermetic Go toolchain; slow)"
mkdir -p "$HOME/.local/bin"
(cd "$CORP_DIR" && ./tool/go build -o "$HOME/.local/bin/gh" ./maintner/gh)
(cd "$CORP_DIR" && ./tool/go build -o "$HOME/.local/bin/mn" ./maintner/mn)

# --- claude plugins --------------------------------------------------------
# i-have-adhd (github.com/ayghri/i-have-adhd) reshapes agent output: lead
# with the next action, number steps, restate state, no preamble/closers.
# Plugin state is runtime-managed by claude, so install via its CLI rather
# than nix. The .i-have-adhd-always marker turns it on for every session.
if command -v claude >/dev/null 2>&1; then
    if ! grep -q '"i-have-adhd@i-have-adhd"' "$HOME/.claude/plugins/installed_plugins.json" 2>/dev/null; then
        log "Installing i-have-adhd claude plugin"
        claude plugin marketplace add ayghri/i-have-adhd
        claude plugin install i-have-adhd@i-have-adhd
    else
        log "i-have-adhd plugin already installed"
    fi
    touch "$HOME/.claude/.i-have-adhd-always"
else
    log "WARN: claude not on PATH; skipping plugin install (re-run bootstrap after home-manager switch)"
fi

# --- verify ---------------------------------------------------------------
log "Checking paseo daemon"
systemctl --user is-active paseo.service >/dev/null 2>&1 || systemctl --user restart paseo.service
sleep 2
if curl -fsS http://127.0.0.1:6767/api/health >/dev/null; then
    log "paseo is healthy"
else
    echo "ERROR: paseo health check failed. Inspect with: systemctl --user status paseo; journalctl --user -u paseo" >&2
    exit 1
fi

cat <<EOF

==> Bootstrap complete.

Connect to paseo from the tailnet:
    paseo --host $(hostname).corp.ts.net:6767
or pair the mobile/desktop app against http://$(hostname).corp.ts.net:6767

Expose a localhost service to the tailnet (e.g. kubectl proxy on 8001):
    expose 8001        # then hit $(hostname):8001 from any tailnet device
    expose -d 8001     # stop
EOF
