# Shared helpers for the LLM-VM workflow CLIs (board/take/chop/taken).
# Sourced, not executed.

LLM_VM="${LLM_VM:-chaosinthecrd-my-precious.corp.ts.net}"
MAINTNER_API="${MAINTNER_API:-http://maintner.corp.ts.net/api/gh}"
BOARD_PROJECT="${BOARD_PROJECT:-173}"   # tailscale org project: Kubernetes & Containers

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
