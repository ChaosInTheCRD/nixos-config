# LLM sandbox VM profile (corp workstation VMs, see LLM-VM.md).
# Adds on top of home-manager-server.nix:
#   - paseo daemon as a systemd user service on port 6767
#   - codex + opencode wired to the Aperture LLM gateway at http://ai
#   - `expose <port>` mechanism to publish localhost services to the tailnet
#   - git insteadOf rewrite so private tailscale repos clone via rogitproxy
#
# Runtime paseo state (~/.paseo/config.json: listen address, hostnames,
# password) is owned by the daemon/CLI and deliberately NOT managed here.
{ config, lib, pkgs, paseoPackage, ... }:

let
  homeDir = config.home.homeDirectory;

  # PATH for paseo and the agent processes it spawns. ~/.local/bin first so
  # maintner's gh shadows any nix-installed gh; then nix profiles (git, node,
  # kubectl, claude, ...); then system paths.
  paseoPath = lib.concatStringsSep ":" [
    "${homeDir}/.local/bin"
    "${homeDir}/.nix-profile/bin"
    "${homeDir}/.local/state/nix/profile/bin"
    "${homeDir}/.local/state/nix/profiles/home-manager/home-path/bin"
    "${homeDir}/go/bin"
    "/nix/var/nix/profiles/default/bin"
    "/usr/local/bin"
    "/usr/bin"
    "/bin"
  ];

  # Binds the tailscale IP specifically: a wildcard bind would collide with
  # the backend service already listening on 127.0.0.1 on the same port.
  exposePort = pkgs.writeShellScript "expose-port" ''
    export PATH="/usr/bin:/usr/sbin:/bin:$PATH"
    addr="$(tailscale ip -4 2>/dev/null | head -1)"
    exec ${pkgs.socat}/bin/socat "TCP-LISTEN:$1,''${addr:+bind=$addr,}fork,reuseaddr" "TCP:127.0.0.1:$1"
  '';

  # Long-lived dev-control-plane service for e2e tests. The actual command
  # is deliberately NOT in this (public) repo — the unit runs
  # ~/.config/testctl/start.sh, which is private and copied over by the
  # bootstrap from the Mac's gitignored scratch copy at
  # the private dots repo (vm-files/testctl-start.sh); revive from
  # there if the VM dies.
  testctlStart = pkgs.writeShellScript "testctl-start" ''
    SCRIPT="$HOME/.config/testctl/start.sh"
    if [ ! -x "$SCRIPT" ]; then
      echo "testctl: $SCRIPT missing or not executable; not starting." >&2
      echo "Install it from the private dots repo: vm-files/testctl-start.sh" >&2
      exit 0
    fi
    exec "$SCRIPT"
  '';

  # State path must match the private start.sh (~/.local/state/testctl) —
  # a reset that wipes a different dir than the service writes silently
  # restarts against the old tailnet DB.
  testctlReset = pkgs.writeShellScriptBin "testctl-reset" ''
    if [ "''${1:-}" != "--force" ] && pgrep -f 'e2e\.test|go test.*k8s-operator/e2e' >/dev/null 2>&1; then
      echo "testctl-reset: an e2e test run appears to be live:" >&2
      pgrep -af 'e2e\.test|go test.*k8s-operator/e2e' >&2
      echo "Resetting mid-run breaks its control tunnel and authkeys (see" >&2
      echo "~/.claude_context.md). Re-run with --force if you are sure." >&2
      exit 1
    fi
    echo "Wiping testctl state (tailnet, devices, scenario credentials)..."
    systemctl --user stop testctl
    rm -rf "$HOME/.local/state/testctl"
    [ -L /tmp/k8s-operator-e2e ] && rm -f /tmp/k8s-operator-e2e
    systemctl --user start testctl
    echo "testctl restarted fresh (first start recompiles; give it a minute)"
  '';

  # First stop for "e2e tests hang / proxies never provision": checks the
  # known failure modes from ~/.claude_context.md and says which remedy
  # applies instead of leaving agents to dig through pod logs.
  testctlDoctor = pkgs.writeShellScriptBin "testctl-doctor" ''
    fail=0
    warn() { echo "WARN: $*"; }
    bad() { echo "FAIL: $*"; fail=1; }
    ok() { echo "ok:   $*"; }

    if systemctl --user is-active --quiet testctl; then
      ok "testctl unit active"
    else
      bad "testctl unit not active — systemctl --user status testctl"
    fi

    restarts=$(systemctl --user show testctl -p NRestarts --value 2>/dev/null)
    if [ "''${restarts:-0}" -gt 0 ]; then
      warn "testctl has auto-restarted $restarts time(s) since load — a restart mid-run breaks that run's tunnel/authkeys (check: journalctl --user -u testctl)"
    else
      ok "no unexpected testctl restarts"
    fi

    if ${pkgs.netcat}/bin/nc -z 127.0.0.1 31544 2>/dev/null; then
      ok "control listening on :31544"
    else
      bad "nothing listening on :31544 — devcontrol still compiling (first start takes minutes; journalctl --user -u testctl -f) or crashed"
    fi

    if [ -L /tmp/k8s-operator-e2e ] && [ -n "$(ls -A /tmp/k8s-operator-e2e 2>/dev/null)" ]; then
      ok "/tmp/k8s-operator-e2e symlink with scenario credentials"
    elif [ -L /tmp/k8s-operator-e2e ]; then
      warn "/tmp/k8s-operator-e2e exists but is empty — wait for devcontrol to finish scenario generation"
    else
      bad "/tmp/k8s-operator-e2e is not a symlink — testctl start.sh hasn't run; restart the unit"
    fi

    if journalctl --user -u testctl --since -30min --no-pager 2>/dev/null \
        | grep -qE 'node [^ ]+ not found|generating MapResponse.*not found'; then
      bad "control is rejecting known nodes ('node not found' in recent logs) — test-tailnet state is corrupted/stale; run testctl-reset (NOT while a run is live)"
    else
      ok "no stale-node errors in recent control logs"
    fi

    if id -nG | grep -qw docker; then
      ok "session has docker group"
    else
      warn "session lacks docker group (lingering user session predates usermod; fixed by VM reboot) — wrap docker/kind/go-test in: sg docker -c '...'"
    fi

    clusters=$(kind get clusters 2>/dev/null || sg docker -c 'kind get clusters' 2>/dev/null)
    if echo "$clusters" | grep -q k8s-operator-e2e; then
      warn "kind cluster k8s-operator-e2e already exists — reused clusters carry stale CRs; delete before a fresh run: kind delete cluster --name k8s-operator-e2e"
    else
      ok "no leftover k8s-operator-e2e kind cluster"
    fi

    if pgrep -f 'e2e\.test|go test.*k8s-operator/e2e' >/dev/null 2>&1; then
      warn "an e2e run appears live — do NOT restart testctl or run testctl-reset until it finishes"
    fi

    exit $fail
  '';

  exposeHelper = pkgs.writeShellScriptBin "expose" ''
    usage() {
      echo "usage: expose <port>       publish localhost:<port> on all interfaces (tailnet)"
      echo "       expose -d <port>    stop publishing <port>"
      echo "       expose -l           list exposed ports"
      exit 1
    }
    case "''${1:-}" in
      -l) systemctl --user list-units 'expose@*' --no-legend ;;
      -d) [ -n "''${2:-}" ] || usage
          systemctl --user stop "expose@$2.service" ;;
      ''' | -h | --help) usage ;;
      *)  systemctl --user start "expose@$1.service"
          echo "localhost:$1 now reachable at $(hostname):$1 on the tailnet" ;;
    esac
  '';
in
{
  home.packages = [
    paseoPackage
    exposeHelper
    testctlReset
    testctlDoctor
    pkgs.socat
    pkgs.codex
    pkgs.opencode
  ];

  systemd.user.startServices = "sd-switch";

  systemd.user.services.paseo = {
    Unit = {
      Description = "Paseo daemon for AI coding agents";
      After = [ "network.target" ];
    };
    Service = {
      ExecStart = "${paseoPackage}/bin/paseo-server";
      Environment = [
        "NODE_ENV=production"
        "PASEO_HOME=${homeDir}/.paseo"
        "PATH=${paseoPath}"
      ];
      Restart = "on-failure";
      RestartSec = 5;
      KillSignal = "SIGTERM";
      TimeoutStopSec = 15;
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  systemd.user.services.testctl = {
    Unit = {
      Description = "Long-lived test-control service for e2e tests";
      After = [ "network.target" ];
    };
    Service = {
      ExecStart = "${testctlStart}";
      Environment = [ "PATH=${paseoPath}" ];
      Restart = "on-failure";
      RestartSec = 10;
      # ./tool/go recompiles on first start after a corp update; be patient
      TimeoutStartSec = 600;
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  # Template unit: `systemctl --user start expose@8001` republishes a
  # localhost-only service (e.g. kubectl proxy) on all interfaces so other
  # tailnet devices can reach it. Wrapped by the `expose` helper above.
  xdg.configFile."systemd/user/expose@.service".text = ''
    [Unit]
    Description=Expose localhost port %i to the tailnet

    [Service]
    ExecStart=${exposePort} %i
    Restart=on-failure
    RestartSec=2
  '';

  # Codex via Aperture (same shape as corp's codex-config.toml; system-level
  # /etc/codex doesn't exist on this VM, so configure per-user).
  home.file.".codex/config.toml".text = ''
    model_provider = "llm-ai-ts-net"

    [model_providers.llm-ai-ts-net]
    name = "Aperture"
    base_url = "http://ai/v1"
    wire_api = "responses"
  '';

  # Opencode via Aperture (per-user variant of corp's opencode.json).
  xdg.configFile."opencode/opencode.json".text = builtins.toJSON {
    "$schema" = "https://opencode.ai/config.json";
    provider = {
      anthropic.options = { baseURL = "http://ai/v1"; apiKey = "-"; };
      openai.options = { baseURL = "http://ai/v1"; apiKey = "-"; };
    };
    enabled_providers = [ "anthropic" "openai" ];
  };

  # Kubeconfig for a cluster shared from the Mac via `vmshare 8001`
  # (kubectl proxy handles auth Mac-side; nothing secret lives here).
  # Usage: kubectl --kubeconfig ~/.kube/shared-cluster.yaml get pods
  home.file.".kube/shared-cluster.yaml".text = ''
    apiVersion: v1
    kind: Config
    clusters:
    - name: shared-cluster
      cluster:
        server: http://127.0.0.1:8001
    contexts:
    - name: shared-cluster
      context:
        cluster: shared-cluster
    current-context: shared-cluster
  '';

  # ~/.local/bin first so maintner's read-only gh (built by the bootstrap
  # script) shadows the real gh from pkgs/dev.nix, which can't auth here.
  programs.zsh.initContent = lib.mkAfter ''
    export PATH="$HOME/.local/bin:$PATH"
  '';

  # Private tailscale-org repos clone via the read-only rogitproxy on the
  # tailnet (no GitHub credentials on the VM).
  programs.git.extraConfig = {
    url."git://rogitproxy/tailscale/" = {
      insteadOf = "https://github.com/tailscale/";
    };
  };
}
