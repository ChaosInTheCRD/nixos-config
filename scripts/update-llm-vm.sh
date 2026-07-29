#!/usr/bin/env bash
# Update everything on the LLM sandbox VM from the Mac, in one shot:
#   1. bump flake.lock here (paseo daemon, claude, codex, opencode, ...)
#   2. sanity-eval the llm profile
#   3. ship flake.lock to the VM and home-manager switch there
#      (systemd sd-switch restarts paseo automatically if its package changed)
#   4. pull ~/Git/corp and rebuild maintner gh/mn
#
# Usage: make update-llm            (or VM=<name> make update-llm)
#        NO_FLAKE_UPDATE=1 ...      skip step 1 (ship current lock as-is)
#
# Note: this leaves the flake.lock bump uncommitted on the Mac — review and
# commit it like any other change.

set -euo pipefail

[ -f "$HOME/.config/llm-vm/env" ] && . "$HOME/.config/llm-vm/env"
VM="${VM:-${LLM_VM:?VM/LLM_VM not set — install ~/.config/llm-vm/env from the private dots repo}}"
SSH_USER="${SSH_USER:-$USER}"
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
NIX_CONFIG="experimental-features = nix-command flakes"
export NIX_CONFIG

log() { echo "==> $*"; }

cd "$REPO_DIR"

if [ -z "${NO_FLAKE_UPDATE:-}" ]; then
    log "Updating flake inputs on the Mac"
    nix flake update
else
    log "Skipping flake update (NO_FLAKE_UPDATE set)"
fi

log "Sanity check: evaluating llm profile"
nix eval '.#homeConfigurations."llm@x86_64-linux".activationPackage' \
    --impure --apply builtins.typeOf >/dev/null

log "Shipping flake.lock to $VM"
scp -o BatchMode=yes flake.lock "$SSH_USER@$VM:Git/nixos-config/flake.lock"

log "Switching home-manager on the VM (this may download a lot)"
ssh -o BatchMode=yes "$SSH_USER@$VM" '
set -euo pipefail
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh 2>/dev/null || true
export PATH="/nix/var/nix/profiles/default/bin:$HOME/.local/state/nix/profiles/home-manager/home-path/bin:$PATH"
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
cd ~/Git/nixos-config
NIX_CONFIG="experimental-features = nix-command flakes" \
    nix run home-manager/master -- switch -b backup --flake ".#llm@x86_64-linux" --impure 2>&1 \
    | grep -vE "^trace: warning|has been renamed" | tail -8

echo "==> Updating corp checkout + maintner tools"
# the corp checkout may have been created by aif pushes (no remotes at all);
# give it a read-only origin so we can fetch
git -C ~/Git/corp remote get-url origin >/dev/null 2>&1 || \
    git -C ~/Git/corp remote add origin git://rogitproxy/tailscale/corp
# corp may sit on a work branch; only fast-forward when tracking is clean
git -C ~/Git/corp fetch origin
if git -C ~/Git/corp symbolic-ref -q HEAD >/dev/null && git -C ~/Git/corp rev-parse -q --verify "@{u}" >/dev/null 2>&1; then
    git -C ~/Git/corp merge --ff-only "@{u}" || echo "WARN: corp not fast-forwarded (diverged/dirty); maintner tools built from current checkout"
else
    echo "WARN: corp on a non-tracking branch ($(git -C ~/Git/corp branch --show-current)); maintner tools built from current checkout"
fi
(cd ~/Git/corp && ./tool/go build -o ~/.local/bin/gh ./maintner/gh && ./tool/go build -o ~/.local/bin/mn ./maintner/mn)

echo "==> Versions now on the VM:"
printf "  paseo:  "; paseo --version 2>/dev/null || echo "?"
printf "  claude: "; claude --version 2>/dev/null || echo "?"
printf "  codex:  "; codex --version 2>/dev/null || echo "?"

systemctl --user is-active paseo.service >/dev/null || systemctl --user restart paseo.service
sleep 2
curl -fsS http://127.0.0.1:6767/api/health >/dev/null && echo "==> paseo healthy"
'

log "Done. Review + commit the flake.lock bump here when happy."
