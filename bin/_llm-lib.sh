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
