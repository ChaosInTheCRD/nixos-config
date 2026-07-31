# Shared helpers for the LLM-VM workflow CLIs (board/take/chop/taken).
# Sourced, not executed.

# Internal values (VM hostname, API endpoints, board number) live in a
# private repo; install its env file to ~/.config/llm-vm/env. Env vars
# still override, and the old defaults apply if the file is absent.
[ -f "$HOME/.config/llm-vm/env" ] && . "$HOME/.config/llm-vm/env"
LLM_VM="${LLM_VM:?LLM_VM not set — install ~/.config/llm-vm/env from the private dots repo}"
MAINTNER_API="${MAINTNER_API:?MAINTNER_API not set — install ~/.config/llm-vm/env}"
BOARD_PROJECT="${BOARD_PROJECT:?BOARD_PROJECT not set — install ~/.config/llm-vm/env}"

llm_ssh() {
    ssh -o BatchMode=yes "$LLM_VM" "$@"
}

maintner_query() { # $1=method $2=params-json
    curl -fsS --max-time 30 -X POST "$MAINTNER_API" \
        -H "Content-Type: application/json" \
        -d "{\"method\":\"$1\",\"params\":$2}"
}

# Normalize an issue ref: corp#123 / tailscale#123 / owner/repo#123 -> owner/repo and number
parse_issue_ref() { # sets REPO, NUM
    local ref="$1"
    case "$ref" in
        */*#*) REPO="${ref%#*}"; NUM="${ref##*#}" ;;
        *#*)   REPO="tailscale/${ref%#*}"; NUM="${ref##*#}" ;;
        *) echo "error: can't parse issue ref '$ref' (want e.g. corp#123 or tailscale/corp#123)" >&2; return 1 ;;
    esac
    [[ "$NUM" =~ ^[0-9]+$ ]] || { echo "error: bad issue number in '$ref'" >&2; return 1; }
}

# Repo checkout path on the VM ($HOME-relative)
vm_repo_dir() { # $1=owner/repo
    echo "Git/$(basename "$1")"
}

# Create a paseo workspace on the VM; echoes "<workspace-id>\t<cwd>".
# Args are passed through to `paseo workspace create` (e.g. --isolation,
# --path, --title, --mode/--new-branch/--worktree-slug for worktrees).
vm_workspace_create() {
    llm_ssh "export PATH=\"\$HOME/.nix-profile/bin:\$PATH\"; paseo workspace create $(printf '%q ' "$@") --json" \
        | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["workspaceId"] + "\t" + d["cwd"])'
}

# Terse workspace title from free text: lowercase, punctuation stripped,
# first 4 words ("tsrecorder: authkey renewal doesn't..." -> "tsrecorder authkey renewal doesnt")
ws_title_from() { # $1=text
    printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -d "'" \
        | sed -E 's/[^a-z0-9]+/ /g; s/^ +//; s/ +$//' | cut -d' ' -f1-4
}

# Run kubeshare (fzf multi-select) and set CLUSTER_NOTE for agent prompts.
# Usage: share_clusters_note || exit 1; then embed $CLUSTER_NOTE in the prompt.
share_clusters_note() {
    "$(dirname "${BASH_SOURCE[0]}")/kubeshare" || return 1
    CLUSTER_NOTE="
I have shared live Kubernetes clusters from my machine SPECIFICALLY for this
task — I expect you to use them (verify against the real cluster, don't just
reason from code). See them with:
  kubectl --kubeconfig ~/.kube/shared-contexts.yaml config get-contexts
and target one with '--context <name>'. Read/apply as the task needs, but
never delete resources you didn't create. If the connection drops mid-task
(the tunnel dies if my Mac sleeps), note it in the log and continue without."
}
